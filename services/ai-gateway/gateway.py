#!/usr/bin/env python3
"""OpenAI-compatible AI Gateway with RAG and PII scrubbing"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import requests
import logging
import time
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")

try:
    from qdrant_client import QdrantClient
    from sentence_transformers import SentenceTransformer
    _qdrant = QdrantClient(url="http://localhost:6333")
    _embedder = SentenceTransformer('BAAI/bge-m3')
    RAG_AVAILABLE = True
except Exception:
    RAG_AVAILABLE = False

try:
    from presidio_analyzer import AnalyzerEngine
    from presidio_anonymizer import AnonymizerEngine
    _analyzer = AnalyzerEngine()
    _anonymizer = AnonymizerEngine()
    PII_AVAILABLE = True
except Exception:
    PII_AVAILABLE = False

RAG_COLLECTION = "documents"
RAG_TOP_K = 3
RAG_THRESHOLD = 0.45

app = FastAPI(title="LLM Cluster Gateway")
security = HTTPBearer()

QUEUE_URL = "http://localhost:8083"
API_KEY_FILE = Path(__file__).parent / "api_key.txt"


def load_api_keys() -> set:
    if API_KEY_FILE.exists():
        return set(API_KEY_FILE.read_text().splitlines())
    return set()


def verify_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
    keys = load_api_keys()
    if keys and credentials.credentials not in keys:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return credentials.credentials


def retrieve_context(query: str) -> str:
    """Search Qdrant for relevant chunks; returns empty string if nothing passes threshold."""
    try:
        vector = _embedder.encode(query).tolist()
        hits = _qdrant.query_points(
            collection_name=RAG_COLLECTION,
            query=vector,
            limit=RAG_TOP_K,
            score_threshold=RAG_THRESHOLD,
        ).points
        if not hits:
            return ""
        parts = [
            f"[Source: {h.payload.get('filename', 'unknown')}]\n{h.payload.get('text', '')}"
            for h in hits
        ]
        return "\n\n---\n".join(parts)
    except Exception:
        return ""


def inject_rag(messages: list) -> list:
    """Prepend retrieved context as a system message when relevant documents are found."""
    user_msgs = [m for m in messages if m.get("role") == "user"]
    if not user_msgs:
        return messages
    context = retrieve_context(user_msgs[-1].get("content", ""))
    if not context:
        return messages
    system_content = (
        "Use the following documents from the knowledge base to answer the user's question "
        "when relevant. If the documents are not relevant, answer normally.\n\n"
        f"---\n{context}\n---"
    )
    msgs = list(messages)
    if msgs and msgs[0].get("role") == "system":
        msgs[0] = {"role": "system", "content": system_content + "\n\n" + msgs[0]["content"]}
    else:
        msgs.insert(0, {"role": "system", "content": system_content})
    return msgs


def scrub_pii(text: str, language: str = "en") -> str:
    """Replace PII entities with <ENTITY_TYPE> placeholders, keeping IP addresses intact."""
    results = _analyzer.analyze(text=text, language=language)
    results = [r for r in results if r.entity_type != "IP_ADDRESS"]
    return _anonymizer.anonymize(text=text, analyzer_results=results).text


def scrub_messages(messages: list) -> list:
    """Scrub PII from user and system message content."""
    scrubbed = []
    for m in messages:
        if m.get("role") in ("user", "system") and isinstance(m.get("content"), str):
            scrubbed.append({**m, "content": scrub_pii(m["content"])})
        else:
            scrubbed.append(m)
    return scrubbed


class ChatRequest(BaseModel):
    model: str = "phi4:latest"
    messages: list
    stream: bool = False
    use_rag: bool = True
    scrub_pii: bool = True
    show_log: bool = False


@app.post("/v1/chat/completions")
async def chat(req: ChatRequest, key: str = Depends(verify_key)):
    _logs = []

    def log(msg):
        logging.info(msg)
        if req.show_log:
            _logs.append(msg)

    log(f"[1] Request received  model={req.model} rag={req.use_rag} pii={req.scrub_pii}")
    messages = req.messages

    if req.use_rag and RAG_AVAILABLE:
        messages = inject_rag(messages)
        log(f"[2] RAG injected      context added from Qdrant")
    else:
        log(f"[2] RAG skipped")

    if req.scrub_pii and PII_AVAILABLE:
        messages = scrub_messages(messages)
        log(f"[3] PII scrubbed      Presidio applied")
    else:
        log(f"[3] PII skipped")

    log(f"[4] Forwarding        → LiteLLM :8083 model={req.model}")
    t0 = time.time()
    resp = requests.post(
        f"{QUEUE_URL}/v1/chat/completions",
        json={"model": req.model, "messages": messages, "stream": req.stream},
        headers={"Authorization": "Bearer sk-llm-cluster"},
        timeout=600,
    )
    elapsed = time.time() - t0
    if resp.status_code == 200:
        data = resp.json()
        usage = data.get("usage", {})
        prompt_tok  = usage.get("prompt_tokens", 0)
        compl_tok   = usage.get("completion_tokens", 0)
        total_tok   = usage.get("total_tokens", 0)
        tok_s = compl_tok / elapsed if elapsed > 0 else 0
        log(
            f"[5] Done  model={req.model}  "
            f"prompt={prompt_tok}  completion={compl_tok}  total={total_tok}  "
            f"time={elapsed:.1f}s  speed={tok_s:.1f} tok/s"
        )
        if req.show_log:
            data["_stats"] = {
                "model": req.model,
                "prompt_tokens": prompt_tok,
                "completion_tokens": compl_tok,
                "total_tokens": total_tok,
                "time_s": round(elapsed, 1),
                "tok_s": round(tok_s, 1),
                "logs": _logs,
            }
        return data
    raise HTTPException(status_code=resp.status_code, detail="Inference failed")


@app.get("/v1/models")
async def list_models(key: str = Depends(verify_key)):
    return {"object": "list", "data": [
        {"id": "phi4:latest",                        "object": "model", "owned_by": "llm-01"},
        {"id": "qwen2.5:32b-instruct-q4_K_M",        "object": "model", "owned_by": "llm-02,llm-03"},
        {"id": "deepseek-coder:33b-instruct-q4_K_M", "object": "model", "owned_by": "llm-03"},
        {"id": "exo:Qwen3.6-35B-A3B-8bit",           "object": "model", "owned_by": "llm-01,llm-02,llm-03"},
    ]}


@app.get("/health")
async def health():
    return {"status": "healthy", "rag": RAG_AVAILABLE, "pii_scrubbing": PII_AVAILABLE}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8082)
