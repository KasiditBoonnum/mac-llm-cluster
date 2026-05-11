#!/usr/bin/env python3
"""OpenAI-compatible AI Gateway"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import requests
import os
from pathlib import Path

app = FastAPI(title="LLM Cluster Gateway")
security = HTTPBearer()

QUEUE_URL = "http://localhost:8080"
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


class ChatRequest(BaseModel):
    model: str = "qwen2.5:32b-instruct-q4_K_M"
    messages: list
    stream: bool = False


@app.post("/v1/chat/completions")
async def chat(req: ChatRequest, key: str = Depends(verify_key)):
    prompt = "\n".join(f"{m['role']}: {m['content']}" for m in req.messages)
    resp = requests.post(f"{QUEUE_URL}/v1/chat/completions",
        json={"model": req.model, "prompt": prompt, "stream": req.stream},
        timeout=600)
    if resp.status_code == 200:
        return resp.json()
    raise HTTPException(status_code=resp.status_code, detail="Inference failed")


@app.get("/v1/models")
async def list_models(key: str = Depends(verify_key)):
    return {"object": "list", "data": [
        {"id": "phi4:14b-q5_K_M", "object": "model"},
        {"id": "qwen2.5:32b-instruct-q4_K_M", "object": "model"},
        {"id": "deepseek-coder-v2:33b-instruct-q4_K_M", "object": "model"},
        {"id": "exo:qwen3-30b", "object": "model"},
    ]}


@app.get("/health")
async def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8082)
