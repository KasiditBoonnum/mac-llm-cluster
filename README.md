# mac-llm-cluster

Private on-premise AI platform running on 3x Apple Mac Studio M4 Max.
All inference stays on local hardware - no cloud, no data leaving the network.

> Full technical documentation: [docs/PLATFORM_OVERVIEW.md](docs/PLATFORM_OVERVIEW.md)

---

## Hardware

| Node | IP | Role | RAM | Storage |
|------|----|------|-----|---------|
| llm-01 | 192.168.10.11 | Primary (all services) | 36 GB | 512 GB |
| llm-02 | 192.168.10.12 | Inference (Qwen 2.5 32B) | 36 GB | 512 GB |
| llm-03 | 192.168.10.13 | Dynamic (Qwen 2.5 / DeepSeek) | 36 GB | 512 GB |

Switch: TP-LINK SX3008F 10 GbE, MTU 9000 (jumbo frames)

---

## Access

| URL | Service | Auth |
|-----|---------|------|
| `https://llm-01.local` | Web UI (chat) | Basic auth |
| `https://llm-01.local:8443/v1/` | AI Gateway API | API key (optional) |
| `https://llm-01.local:8444/admin` | RAG Admin | Basic auth |
| `http://llm-01.local:3001` | Grafana dashboards | - |

---

## Production Models

| Model | Quantization | Node | Use |
|-------|-------------|------|-----|
| Phi-4 14B | q5_K_M | llm-01 | Fast general tasks |
| Qwen 2.5 32B | q4_K_M | llm-02 / llm-03 | Complex reasoning |
| DeepSeek Coder V2 33B | q4_K_M | llm-03 (auto-switch) | Code tasks |
| Qwen3.6-35B-A3B-8bit | 8bit MLX | All 3 nodes (Exo) | Large context (65,536 tokens) |

Additional Qwen3 variants (4B, 8B, 14B, 30B, 32B) are installed for testing only.

---

## Services (Node 1)

| Port | Service |
|------|---------|
| 443 | Nginx - Web UI (HTTPS) |
| 3001 | Grafana |
| 5678 | Exo distributed inference |
| 6333 | Qdrant vector DB |
| 8080 | Queue Manager |
| 8081 | RAG Server |
| 8082 | AI Gateway |
| 8083 | LiteLLM proxy |
| 8443 | Nginx - Gateway API (HTTPS) |
| 8444 | Nginx - RAG Admin (HTTPS) |
| 9090 | Prometheus |

SSH tunnels on Node 1: `localhost:11435` → llm-02:11434, `localhost:11436` → llm-03:11434

---

## Quick API Usage

Pipe through `llm-parse.py` for readable output. From inside the cluster (Node 1), use HTTP on port 8082 directly; from outside, use HTTPS on port 8443.

```bash
# Ollama model - from Node 1 (internal, no TLS)
curl -s http://llm-01.local:8082/v1/chat/completions \
  -H "Authorization: Bearer x" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:32b-instruct-q4_K_M",
    "messages": [{"role": "user", "content": "your question here"}],
    "use_rag": true,
    "scrub_pii": true,
    "show_log": true
  }' | python3 ~/mac-llm-cluster/scripts/gateway/llm-parse.py

# Exo distributed model - from Node 1
curl -s http://llm-01.local:8082/v1/chat/completions \
  -H "Authorization: Bearer x" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "exo:Qwen3.6-35B-A3B-8bit",
    "messages": [{"role": "user", "content": "your question here"}],
    "use_rag": true,
    "scrub_pii": true,
    "show_log": true
  }' | python3 ~/mac-llm-cluster/scripts/gateway/llm-parse.py

# From outside the cluster (HTTPS via Nginx)
curl -sk https://llm-01.local:8443/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "phi4:latest", "messages": [{"role": "user", "content": "Hello"}]}'

# List available models
curl -s http://llm-01.local:8082/v1/models

# Health check
curl -s http://llm-01.local:8082/health
```

**Valid model names** (must match exactly):

| Model ID | Node |
|----------|------|
| `phi4:latest` | llm-01 |
| `qwen2.5:32b-instruct-q4_K_M` | llm-02 |
| `qwen2.5:32b-instruct-q4_K_M-node3` | llm-03 |
| `deepseek-coder:33b-instruct-q4_K_M` | llm-03 |
| `exo:Qwen3.6-35B-A3B-8bit` | all 3 nodes |

---

## Repository Structure

```
config/     Nginx, Prometheus, Grafana, LaunchAgent plists, SSH, Ollama model lists
scripts/    Deploy, hardening, monitoring, health checks, Exo helpers
services/   Python microservices (gateway, queue, rag, privacy, monitoring, chatops, webui)
tests/      Integration and stress tests
docs/       Full platform documentation
logs/       Analysis output and audit logs
```

---

## Key Scripts

| Script | Purpose |
|--------|---------|
| `scripts/deploy/deploy-all-nodes.sh` | Full 8-phase cluster deployment |
| `scripts/health/check-services.sh` | Service health check across all nodes |
| `scripts/exo/exo-restart.sh` | Restart Exo on all 3 nodes |
| `scripts/hardening/enterprise-hardening.sh` | Security hardening |

---

## Gateway Request Pipeline

Every API request through the Gateway:

1. API key validation (optional - open if `api_key.txt` absent)
2. RAG retrieval from Qdrant (top-5 chunks, threshold 0.25, Thai synonym expansion)
3. PII scrubbing via Presidio (IP addresses preserved)
4. Per-node semaphore (1 concurrent inference per node)
5. Route: `exo` model name → Exo :5678; others → LiteLLM :8083

---

## Notes

- **This dev MacBook is not connected to the live cluster** - push changes and deploy via SSH.
- **Exo patch required:** After installing Exo, set `EXO_MAX_INSTANCE_RETRIES = 50000` in `~/exo-source/src/exo/shared/constants.py` (default 5 is too low for large model downloads).
- **Discord bot:** Code and LaunchAgent are ready in `services/chatops/` - set `DISCORD_BOT_TOKEN` to activate.
