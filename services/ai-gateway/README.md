# AI Gateway

OpenAI-compatible API gateway with RAG, PII scrubbing, and load balancing via LiteLLM.

## Architecture

```
Client
  ↓
gateway.py :8082       ← RAG injection + PII scrubbing (Presidio)
  ↓
LiteLLM proxy :8083    ← Load balancing + auto model selection
  ↓
queue_manager :8080    ← Intelligent routing (Exo, node switching, idle timeout)
  ↓          ↓          ↓
llm-01      llm-02     llm-03
phi4        qwen2.5    qwen2.5
:11434      :11434     :11434
```

## Features

### PII Scrubbing (Presidio)
ตรวจหาและแทนที่ข้อมูลส่วนตัวก่อนส่งไป LLM โดยใช้ Microsoft Presidio + spaCy

PII scrubbing เกิดขึ้นที่ **gateway.py** ก่อน request จะถึง LiteLLM หรือ LLM nodes — ทุก request ที่ผ่าน gateway จะถูก enforce โดยอัตโนมัติ

| Entity | ตัวอย่าง | ผลลัพธ์ |
|---|---|---|
| ชื่อ | John Smith | `<PERSON>` |
| อีเมล | john@gmail.com | `<EMAIL_ADDRESS>` |
| เบอร์โทร | 055-123-4567 | `<PHONE_NUMBER>` |
| บัตรเครดิต | 4111-1111-1111-1111 | `<CREDIT_CARD>` |
| IP | 192.168.1.1 | `<IP_ADDRESS>` |

### RAG (Retrieval-Augmented Generation)
ดึง context จาก Qdrant vector database และ inject เป็น system message

### Load Balancing + Auto Model Selection (LiteLLM)
กระจาย request ระหว่าง nodes อัตโนมัติด้วย `least-busy` routing — ไม่ต้องระบุ model ก็ได้ ใช้ `"model": "auto"` แล้ว LiteLLM จะเลือก node ที่ว่างที่สุดให้

### Intelligent Routing (Queue Manager)
queue_manager :8080 จัดการ:
- **Exo switching** — โหลด/ปิด distributed inference อัตโนมัติ
- **Node 3 model switching** — สลับระหว่าง Qwen ↔ DeepSeek ตาม request
- **Idle timeout** — คืน VRAM เมื่อไม่ใช้งาน

## Installation

```bash
cd ~/mac-llm-cluster

# 1. รัน install script (ทำทุกอย่างอัตโนมัติ)
bash scripts/gateway/install-gateway.sh

# 2. เปิด SSH tunnels ไป llm-02/llm-03
ssh -N -f -L 11435:localhost:11434 llm-02
ssh -N -f -L 11436:localhost:11434 llm-03
```

### Dependencies
- Python 3.12 (venv ที่ `services/ai-gateway/.venv`)
- `presidio-analyzer`, `presidio-anonymizer` — PII detection
- `spacy` + `en_core_web_lg` — NER model สำหรับ Presidio
- `litellm[proxy]` — API gateway และ load balancer

## After Reboot

launchd จัดการ auto-start ให้อัตโนมัติ ยกเว้น SSH tunnels:

```bash
ssh -N -f -L 11435:localhost:11434 llm-02
ssh -N -f -L 11436:localhost:11434 llm-03
ssh -N -f -L 11437:localhost:11435 llm-03
```

> **หมายเหตุ:** SSH tunnel จำเป็นเพราะ macOS 15 (Sequoia) บล็อก Python (Homebrew)
> จากการเชื่อมต่อ local network โดยตรง (TCC - Transparency, Consent, and Control)

## Services

| Service | Port | launchd Label |
|---|---|---|
| AI Gateway | 8082 | `com.llm.ai-gateway` |
| LiteLLM Proxy | 8083 | `com.llm.litellm-proxy` |
| Queue Manager | 8080 | `com.llm.queue-manager` |

## Health Check

```bash
# Gateway + PII scrubbing
curl http://localhost:8082/health
# → {"status":"healthy","rag":true,"pii_scrubbing":true}

# LiteLLM + nodes
curl http://localhost:8083/health -H "Authorization: Bearer sk-llm-cluster"
# → {"healthy_count":3,"unhealthy_count":0,...}
```

## API Usage

### Chat (with PII scrubbing)
```bash
curl -X POST http://llm-01.local:8082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_KEY>" \
  -d '{
    "model": "phi4:latest",
    "messages": [{"role": "user", "content": "..."}],
    "scrub_pii": true
  }'
```

### Chat (without PII scrubbing)
```bash
curl -X POST http://llm-01.local:8082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_KEY>" \
  -d '{
    "model": "qwen2.5:32b-instruct-q4_K_M",
    "messages": [{"role": "user", "content": "..."}],
    "scrub_pii": false
  }'
```

### Available Models
| Model | Node |
|---|---|
| `auto` | LiteLLM เลือก node ที่ว่างที่สุด |
| `phi4:latest` | llm-01 |
| `qwen2.5:32b-instruct-q4_K_M` | llm-02, llm-03 (load balanced) |
| `deepseek-coder:33b-instruct-q4_K_M` | llm-03 |
| `exo:Qwen3.6-35B-A3B-8bit` | llm-01, llm-02, llm-03 (distributed) |

## Logs

```bash
tail -f /tmp/ai-gateway.log      # Gateway logs
tail -f /tmp/ai-gateway.err      # Gateway errors
tail -f /tmp/litellm-proxy.log   # LiteLLM logs
tail -f /tmp/queue-manager.log   # Queue logs
```

## Files

```
services/ai-gateway/
├── gateway.py              # Main gateway (RAG + PII scrubbing)
├── litellm_config.yaml     # LiteLLM routing config (ชี้หา queue_manager :8080)
├── presidio_callback.py    # Presidio callback class (reserved for future use)
├── requirements.txt        # Python dependencies
└── api_key.txt             # API keys (optional, ถ้าไม่มีจะ allow ทุก key)

config/launchd/
├── com.llm.ai-gateway.plist
├── com.llm.litellm-proxy.plist
├── com.llm.ssh-tunnel-llm02.plist
└── com.llm.ssh-tunnel-llm03.plist
```