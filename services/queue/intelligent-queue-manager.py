#!/usr/bin/env python3
"""Intelligent Queue Manager with Model Switching"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import asyncio
import time
import subprocess
import uuid
from datetime import datetime
from collections import deque

# Characters invalid inside JSON strings (control chars except \t \n \r)
_CTRL_STRIP = dict.fromkeys(
    list(range(0x00, 0x09)) + [0x0b, 0x0c] + list(range(0x0e, 0x20)) + [0x7f]
)

app = FastAPI()

OLLAMA_NODES = {
    "phi4":  "http://llm-01.local:11434",   # phi4:latest
    "qwen":  "http://llm-02.local:11434",   # qwen2.5:32b-instruct-q4_K_M
    "node3": "http://llm-03.local:11434",   # qwen2.5:32b-instruct-q4_K_M / deepseek-coder:33b-instruct-q4_K_M (switches)
}

EXO_ENDPOINT = "http://llm-01.local:5678"
EXO_IDLE_TIMEOUT = 300    # 5 minutes
NODE3_IDLE_TIMEOUT = 900  # 15 minutes


class State:
    def __init__(self):
        self.queue = deque()
        self.active_tasks = {}
        self.current_mode = "ollama"
        self.node3_model = "qwen"
        self.node3_last_deepseek = None
        self.exo_last_use = None
        self.exo_loaded = False


state = State()


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str
    messages: list[ChatMessage]
    stream: bool = False


def is_exo_model(model: str) -> bool:
    return "exo" in model.lower()


def is_phi_model(model: str) -> bool:
    return "phi" in model.lower()


def is_deepseek_model(model: str) -> bool:
    return "deepseek" in model.lower() or "code" in model.lower()


def switch_node3_to_deepseek():
    if state.node3_model == "deepseek":
        return
    print(f"[{datetime.now()}] Node 3: Qwen → DeepSeek")
    requests.post(f"{OLLAMA_NODES['node3']}/api/generate",
        json={"model": "qwen2.5:32b-instruct-q4_K_M", "prompt": "", "keep_alive": 0},
        timeout=10)
    time.sleep(2)
    requests.post(f"{OLLAMA_NODES['node3']}/api/generate",
        json={"model": "deepseek-coder:33b-instruct-q4_K_M", "prompt": "", "keep_alive": -1},
        timeout=30)
    state.node3_model = "deepseek"
    state.node3_last_deepseek = datetime.now()
    print(f"[{datetime.now()}] ✅ Node 3 switched to DeepSeek")


def switch_node3_to_qwen():
    if state.node3_model == "qwen":
        return
    print(f"[{datetime.now()}] Node 3: DeepSeek → Qwen")
    requests.post(f"{OLLAMA_NODES['node3']}/api/generate",
        json={"model": "deepseek-coder:33b-instruct-q4_K_M", "prompt": "", "keep_alive": 0},
        timeout=10)
    time.sleep(2)
    requests.post(f"{OLLAMA_NODES['node3']}/api/generate",
        json={"model": "qwen2.5:32b-instruct-q4_K_M", "prompt": "", "keep_alive": -1},
        timeout=30)
    state.node3_model = "qwen"
    state.node3_last_deepseek = None
    print(f"[{datetime.now()}] ✅ Node 3 switched to Qwen")


def load_exo():
    if state.exo_loaded:
        return
    print(f"[{datetime.now()}] Loading Exo on all 3 nodes...")
    subprocess.Popen([
        "exo", "run",
        "--nodes", "llm-01.local:5678,llm-02.local:5678,llm-03.local:5678",
        "--model", "Qwen3.6-35B-A3B-8bit",
        "--context-size", "65536",
        "--kv-cache-type", "q16_0",
        "--listen", "0.0.0.0:5678"
    ], stdout=subprocess.DEVNULL)
    for node in ["llm-02.local", "llm-03.local"]:
        subprocess.run(["ssh", node, "exo worker --coordinator llm-01.local:5678 --listen 0.0.0.0:5678 &"],
                       stdout=subprocess.DEVNULL, shell=False)
    time.sleep(15)
    state.exo_loaded = True
    state.current_mode = "exo"
    state.exo_last_use = datetime.now()
    print(f"[{datetime.now()}] ✅ Exo loaded")


def unload_exo():
    if not state.exo_loaded:
        return
    print(f"[{datetime.now()}] Unloading Exo...")
    subprocess.run(["pkill", "-f", "exo"], stdout=subprocess.DEVNULL)
    for node in ["llm-02.local", "llm-03.local"]:
        subprocess.run(["ssh", node, "pkill -f exo"], stdout=subprocess.DEVNULL)
    state.exo_loaded = False
    state.current_mode = "ollama"
    state.exo_last_use = None
    print(f"[{datetime.now()}] ✅ Exo unloaded")


COMPLETED_TASK_TTL = 300  # keep completed/error results for 5 minutes


def check_idle_timeouts():
    now = datetime.now()
    # Clean up old completed/error tasks
    expired = [
        tid for tid, t in state.active_tasks.items()
        if t.get("status") in ("completed", "error")
        and (now - datetime.fromisoformat(t["completed_at"])).total_seconds() > COMPLETED_TASK_TTL
    ]
    for tid in expired:
        state.active_tasks.pop(tid, None)
    if state.node3_model == "deepseek" and state.node3_last_deepseek:
        idle = (now - state.node3_last_deepseek).total_seconds()
        if idle > NODE3_IDLE_TIMEOUT:
            print(f"Node 3 idle for {idle:.0f}s, switching to Qwen")
            switch_node3_to_qwen()
    if state.exo_loaded and state.exo_last_use:
        idle = (now - state.exo_last_use).total_seconds()
        if idle > EXO_IDLE_TIMEOUT:
            print(f"Exo idle for {idle:.0f}s, unloading")
            unload_exo()


async def process_queue():
    while True:
        check_idle_timeouts()
        if not state.queue:
            await asyncio.sleep(1)
            continue
        task = state.queue[0]
        request = task['request']
        if is_exo_model(request.model):
            if state.current_mode == "ollama" and state.active_tasks:
                await asyncio.sleep(1)
                continue
            if not state.exo_loaded:
                load_exo()
        else:
            if state.current_mode == "exo":
                await asyncio.sleep(1)
                continue
        task = state.queue.popleft()
        asyncio.create_task(process_task(task))
        await asyncio.sleep(0.1)


async def process_task(task):
    task_id = task['task_id']
    request = task['request']
    done_event = task.get('done_event')
    state.active_tasks[task_id] = {
        "status": "running",
        "model": request.model,
        "start_time": datetime.now().isoformat(),
        "tokens_per_second": 0
    }
    try:
        if is_exo_model(request.model):
            response = await run_exo(task_id, request)
        elif is_deepseek_model(request.model):
            switch_node3_to_deepseek()
            response = await run_ollama(task_id, request, OLLAMA_NODES['node3'])
            state.node3_last_deepseek = datetime.now()
        elif is_phi_model(request.model):
            response = await run_ollama(task_id, request, OLLAMA_NODES['phi4'])
        else:
            response = await run_ollama(task_id, request, OLLAMA_NODES['qwen'])
        state.active_tasks[task_id]["status"] = "completed"
        state.active_tasks[task_id]["result"] = response
        state.active_tasks[task_id]["completed_at"] = datetime.now().isoformat()
    except Exception as e:
        state.active_tasks[task_id]["status"] = "error"
        state.active_tasks[task_id]["error"] = str(e)
        state.active_tasks[task_id]["completed_at"] = datetime.now().isoformat()
    finally:
        if done_event:
            done_event.set()


def _to_openai_response(result: dict, model: str) -> dict:
    """Normalize Ollama /api/chat or Exo response to OpenAI format."""
    # Exo already returns OpenAI format
    if "choices" in result:
        return result
    # Ollama /api/chat returns {"message": {"role": ..., "content": ...}, "eval_count": N, ...}
    content = result.get("message", {}).get("content", "")
    if isinstance(content, str):
        content = content.translate(_CTRL_STRIP)
    completion_tokens = result.get("eval_count", 0)
    prompt_tokens = result.get("prompt_eval_count", 0)
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:12]}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model,
        "choices": [{"index": 0, "message": {"role": "assistant", "content": content}, "finish_reason": "stop"}],
        "usage": {"prompt_tokens": prompt_tokens, "completion_tokens": completion_tokens, "total_tokens": prompt_tokens + completion_tokens},
    }


async def run_ollama(task_id, request, node_url):
    start = time.time()
    messages = [{"role": m.role, "content": m.content} for m in request.messages]
    response = requests.post(f"{node_url}/api/chat",
        json={"model": request.model, "messages": messages, "stream": False},
        timeout=300)
    if response.status_code == 200:
        data = response.json()
        elapsed = time.time() - start
        tokens = data.get("eval_count", 0)
        tok_s = tokens / elapsed if elapsed > 0 else 0
        if task_id in state.active_tasks:
            state.active_tasks[task_id]["tokens_per_second"] = round(tok_s, 2)
        return data
    raise Exception(f"Ollama error: {response.status_code}")


async def run_exo(task_id, request):
    state.exo_last_use = datetime.now()
    start = time.time()
    messages = [{"role": m.role, "content": m.content} for m in request.messages]
    response = requests.post(f"{EXO_ENDPOINT}/v1/chat/completions",
        json={"model": request.model, "messages": messages, "stream": False},
        timeout=600)
    if response.status_code == 200:
        data = response.json()
        elapsed = time.time() - start
        tokens = len(data["choices"][0]["message"]["content"].split())
        tok_s = tokens / elapsed if elapsed > 0 else 0
        if task_id in state.active_tasks:
            state.active_tasks[task_id]["tokens_per_second"] = round(tok_s, 2)
        return data
    raise Exception(f"Exo error: {response.status_code}")


@app.on_event("startup")
async def startup():
    asyncio.create_task(process_queue())


@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    task_id = str(uuid.uuid4())
    done_event = asyncio.Event()
    state.queue.append({
        "task_id": task_id,
        "request": request,
        "queued_at": datetime.now().isoformat(),
        "done_event": done_event,
    })
    await done_event.wait()
    task = state.active_tasks.get(task_id, {})
    if task.get("status") == "error":
        raise HTTPException(status_code=500, detail=task.get("error", "inference failed"))
    return _to_openai_response(task["result"], request.model)


@app.get("/tasks/{task_id}")
async def get_task_status(task_id: str):
    if task_id in state.active_tasks:
        return state.active_tasks[task_id]
    for i, task in enumerate(state.queue):
        if task['task_id'] == task_id:
            return {"status": "queued", "position": i + 1}
    return {"status": "not_found"}


@app.get("/queue/status")
async def get_queue_status():
    return {
        "mode": state.current_mode,
        "queue_length": len(state.queue),
        "active_tasks": len(state.active_tasks),
        "node3_model": state.node3_model,
        "exo_loaded": state.exo_loaded
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
