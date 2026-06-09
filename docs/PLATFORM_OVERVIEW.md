# MAC LLM CLUSTER & AI GATEWAY
## Platform Technical Overview

---

# TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Why We Built This](#why-we-built-this)
3. [What Is an LLM?](#what-is-an-llm)
4. [System Architecture - The Big Picture](#system-architecture)
5. [Hardware: 3× Mac Studio M4 Max](#hardware)
6. [Request Flow - End to End](#request-flow)
7. [Core Components](#core-components)
8. [AI Models](#ai-models)
9. [Security Architecture](#security-architecture)
10. [Automation Capabilities](#automation-capabilities)
11. [Deployment Process](#deployment-process)
12. [Network & Port Reference](#network-architecture)
13. [Use Cases](#use-cases)
14. [Benefits Summary](#benefits-summary)
15. [Technical Reference](#technical-reference)
16. [Planned Upgrades](#planned-upgrades)
17. [Glossary](#glossary)

---

# 1. EXECUTIVE SUMMARY

The **MAC LLM CLUSTER & AI GATEWAY** is an on-premise (self-hosted) artificial intelligence platform built on three Apple Mac Studio computers. It allows an organization to run powerful, state-of-the-art large language models - the same category of AI that powers modern AI assistants - entirely within its own network, without sending any data to external cloud services.

**Three core goals drive this project:**

| Goal | What It Means |
|------|---------------|
| **Development & Testing** | Run and experiment with LLM models in-house, reducing cloud dependency |
| **Data Privacy** | All data stays on organization hardware - nothing leaves the local network |
| **Automation** | Power internal tools: log analysis, automated reporting, AI-assisted workflows |

**In short:** A private, fully open-source AI platform running on your own hardware - completely under your control, with no per-query costs and no external data transmission.

---

# 2. WHY WE BUILT THIS

## The Problem with Cloud AI

When a team uses a cloud-based AI service, every prompt and response travels over the internet to a server the organization does not control:

```
YOUR COMPUTER  ──── internet ────▶  CLOUD SERVER
     │                                    │
 Your data                         Processed externally
 Your secrets                      Privacy concerns
 Your code                         Ongoing subscription costs
```

## Our Solution: On-Premise AI

```
YOUR COMPUTER  ──── local network ────▶  MAC LLM CLUSTER
     │                                         │
 Your data                              Stays on our servers
 Your secrets                           We control everything
 Your code                              No external transmission
```

**What this unlocks:**
- No data leaves the building - full privacy by architecture
- No recurring API fees - hardware is a one-time investment, all software is open-source
- No internet dependency - works when external connectivity is unavailable
- Full model and configuration control
- Complete audit trail of every interaction

---

# 3. WHAT IS AN LLM?

An **LLM (Large Language Model)** is an AI program trained on vast amounts of text. Through training, it learns to understand and generate human language. You give it a task or question; it responds intelligently based on patterns learned from its training data.

```
You type:  "Summarize this error log and tell me what went wrong."
    │
    ▼
  LLM processes it...
    │
    ▼
AI replies: "The server crashed at 14:32 because disk space
             reached 100%. Three services failed to start..."
```

## Models in Production Use

| Model | Parameters | Quantization | Best For |
|-------|-----------|-------------|----------|
| **Phi-4** (14B) | 14 billion | q5_K_M | Fast responses, general tasks |
| **Qwen 2.5** (32B) | 32 billion | q4_K_M | Complex reasoning and analysis |
| **DeepSeek Coder V2** (33B) | 33 billion | q4_K_M | Code writing and review |
| **Qwen3.6-35B** (distributed) | 35 billion | 8bit MLX | Maximum capability, long documents |

> Additional Qwen3 variants (4B, 8B, 14B, 30B, 32B) are installed on the nodes for testing purposes and are not used in regular operations.

> **What does "B" mean?**
> Parameters are the learned values inside the model - roughly analogous to knowledge capacity. More parameters = more capability, but also requires more RAM and compute.

---

# 4. SYSTEM ARCHITECTURE - THE BIG PICTURE

```
╔══════════════════════════════════════════════════════════════════╗
║                    MAC LLM CLUSTER PLATFORM                      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  USERS               NGINX + GATEWAY LAYER         AI LAYER      ║
║  ┌─────────┐  :443   ┌──────────────────┐         ┌────────┐     ║
║  │  Chat   │────────▶│   Web UI (React) │         │ Node 1 │     ║
║  │  Web UI │  HTTPS  │  + Express :8000 │         │ Phi-4  │     ║
║  └─────────┘         └──────────────────┘         └────────┘     ║
║                                                                  ║
║  ┌─────────┐  :8443  ┌──────────────────┐         ┌────────┐     ║
║  │ Scripts │────────▶│  AI Gateway      │────────▶│ Node 2 │     ║
║  │  / API  │  HTTPS  │  :8082 (FastAPI) │         │Qwen2.5 │     ║
║  └─────────┘         │  ✓ PII Scrub     │         └────────┘     ║
║                      │  ✓ RAG           │         ┌────────┐     ║
║                      │  ✓ Semaphore     │────────▶│ Node 3 │     ║
║                      └──────────────────┘         │Dynamic │     ║
║                      ┌──────────────────┐         └────────┘     ║
║                      │  LiteLLM :8083   │                        ║
║                      │  (model router)  │         ┌────────┐     ║
║                      └──────────────────┘    Exo  │ALL 3   │     ║
║                      ┌──────────────────┐   :5678 │ Nodes  │     ║
║                      │  Queue Manager   │────────▶│Qwen3.6 │     ║
║                      │  :8080 (FastAPI) │         └────────┘     ║
║                      └──────────────────┘                        ║ 
║                                                                  ║
║  KNOWLEDGE BASE   :8444  MONITORING                              ║
║  ┌──────────────┐        ┌──────────────────────────────────┐    ║
║  │  RAG Server  │        │ Prometheus :9090 + Grafana :3001 │    ║
║  │  :8081       │        └──────────────────────────────────┘    ║
║  │  Qdrant :6333│                                                ║
║  └──────────────┘                                                ║
╚══════════════════════════════════════════════════════════════════╝
```

---

# 5. HARDWARE: 3× MAC STUDIO M4 MAX

## Physical Setup

```
  ┌────────────────────────────────────────────────────────────┐
  │        TP-LINK SX3008F - 10 Gigabit Ethernet Switch        │
  │            (Jumbo Frames: MTU 9000 for performance)        │
  └──────┬──────────────────────┬──────────────────┬───────────┘
         │   10GbE              │   10GbE          │   10GbE
         ▼                      ▼                  ▼
  ┌────────────┐        ┌────────────┐     ┌────────────┐
  │   llm-01   │        │   llm-02   │     │   llm-03   │
  │  PRIMARY   │        │ INFERENCE  │     │  DYNAMIC   │
  │────────────│        │────────────│     │────────────│
  │ M4 Max     │        │ M4 Max     │     │ M4 Max     │
  │ 36 GB RAM  │        │ 36 GB RAM  │     │ 36 GB RAM  │
  │ 512 GB SSD │        │ 512 GB SSD │     │ 512 GB SSD │
  │────────────│        │────────────│     │────────────│
  │ Nginx      │        │ Qwen2.5    │     │ Qwen2.5    │
  │ Gateway    │        │ (32B)      │     │ (32B)      │
  │ LiteLLM    │        │            │     │   ↕ auto   │
  │ Queue Mgr  │        │            │     │ DeepSeek   │
  │ RAG Server │        │            │     │ Coder (33B)│
  │ Web UI     │        │            │     │            │
  │ Qdrant     │        │            │     │            │
  │ Prometheus │        │            │     │            │
  │ Phi-4 (14B)│        │            │     │            │
  └────────────┘        └────────────┘     └────────────┘
```

## Why Mac Studio M4 Max for AI?

| Feature | Advantage for AI |
|---------|-----------------|
| **Unified Memory** | CPU and GPU share the same 36 GB RAM - a 30B+ model fits in one machine |
| **Apple Neural Engine** | Dedicated on-chip AI acceleration hardware |
| **Memory Bandwidth** | ~410 GB/s - critical for fast model weight access |
| **Energy Efficiency** | ~100W per node at peak load |
| **Form Factor** | Compact - fits in an office or equipment room |

## Cluster Totals

| Resource | Per Node | Total (3 Nodes) |
|----------|----------|-----------------|
| RAM | 36 GB | **108 GB** |
| Storage | 512 GB | **1.5 TB** |
| Chip | M4 Max | 3× M4 Max |

All nodes communicate over **SSH** through the SX3008F 10GbE switch - required by macOS network access policies.

---

# 6. REQUEST FLOW - END TO END

```
Step 1: User sends a message (via Web UI or API)
        "What were the top 5 errors in the logs last week?"

Step 2: RAG searches Qdrant for relevant documents
        Exact filename match attempted first.
        Fallback: semantic similarity (BAAI/bge-m3 embeddings)
        with Thai synonym expansion (threshold 0.25)
        Found: "Server Incident Report Q1-2026.pdf"
        → chunks injected into prompt as context

Step 3: PII Filter scans for sensitive personal data
        "สมชาย มีสุข" → [PERSON]
        "081-234-5678" → [PHONE_NUMBER]
        "192.168.10.50" → kept (IPs are not scrubbed)

Step 4: Gateway acquires per-node semaphore (1 slot per machine)
        Route decision:
          exo model → llm-01.local:5678 (Exo distributed)
          other     → LiteLLM :8083 → SSH tunnel to target node

Step 5: AI generates response

Step 6: Response returned to user with optional _stats block
        "The top 5 errors last week were:
         1. Disk full on Node 3 (12 occurrences)..."
```

### Actual Gateway Log - Single Node Model

```
[1] Request received  model=qwen3:30b-a3b-q4_K_M rag=True pii=True
[2] RAG injected      context found in Qdrant
[3] PII scrubbed      Presidio applied
[4] Forwarding        → LiteLLM :8083 model=qwen3:30b-a3b-q4_K_M
[4a] Queue            waiting for llm-02 slot
[4b] Queue            acquired llm-02 slot
[5] Done
```

### Actual Gateway Log - Exo Distributed Model

```
[1] Request received  model=exo:Qwen3.6-35B-A3B-8bit rag=True pii=True
[2] RAG injected      context added from Qdrant
[3] PII scrubbed      Presidio applied
[4] Forwarding        → Exo :5678 model=mlx-community/Qwen3.6-35B-A3B-8bit
[5] Done
```

---

# 7. CORE COMPONENTS

## 7.1 AI Gateway (`services/ai-gateway/`)

Single entry point for all AI requests. **Port 8082** (internal) | **Port 8443** HTTPS (via Nginx) | Python FastAPI

```
REQUESTS ────────▶  AI GATEWAY (Port 8082)
                    ├─ 1. Optional API key validation
                    │     (reads api_key.txt; open if file absent)
                    ├─ 2. RAG document retrieval (Qdrant :6333)
                    │     Thai synonym expansion → top-5 chunks
                    │     threshold 0.25 cosine similarity
                    ├─ 3. PII scan & selective scrubbing (Presidio)
                    │     IP addresses are preserved
                    ├─ 4. Per-machine semaphore (1 concurrent/node)
                    ├─ 5. Route:
                    │       standard models → LiteLLM proxy (:8083)
                    │       model name contains "exo" → llm-01.local:5678
                    └─ 6. Return response + optional _stats
```

**LiteLLM routing:** latency-based, 120s timeout. Master key: `sk-llm-cluster`.

**OpenAI API compatibility:** Any application already calling an OpenAI-compatible endpoint can redirect to this cluster by changing only the base URL - no code changes needed.

**Request parameters:**
- `use_rag` (default `true`) - toggle RAG retrieval per request
- `scrub_pii` (default `true`) - toggle PII scrubbing per request
- `show_log` (default `false`) - return pipeline trace in `_stats` field

---

## 7.2 Intelligent Queue Manager (`services/queue/`)

Traffic controller for model routing and resource management. **Port 8080** | Python FastAPI

### Dynamic Model Switching (Node 3)

```
Node 3 running: Qwen 2.5 32B (general purpose)
    │
    ▼ Code task detected (model name contains "deepseek" or "code")
    │
Unload Qwen 2.5 → Load DeepSeek Coder V2 33B (~2-3 min)
    │
    ▼ Code question answered by specialized model ✓
    │
15-minute idle → Unload DeepSeek → Reload Qwen 2.5
```

### Exo Distributed Mode

```
NORMAL MODE:                   DISTRIBUTED EXO MODE:
Node 1: [ Phi-4 14B ]          Node 1: ╔══════════════════╗
Node 2: [Qwen 2.5 32B]         Node 2: ║ Qwen3.6-35B      ║
Node 3: [DeepSeek 33B]         Node 3: ║ -A3B-8bit (MLX)  ║
                                       ║ 65,536 ctx tokens║
                                       ╚══════════════════╝
```

5-minute idle timeout: Exo unloads to free resources.

> **Maximum model size:** Exo can distribute any model across the cluster. With 108 GB total unified memory across three nodes, the practical upper limit is approximately **120B parameters** (8-bit quantization).

> **Required patch - model download fix:** The default `EXO_MAX_INSTANCE_RETRIES` in the Exo source is 5, which is too low and causes model downloads to fail. After installing Exo, edit `~/exo-source/src/exo/shared/constants.py` and change it to 50000:
> ```python
> EXO_MAX_INSTANCE_RETRIES = 50000  # was 5 - too low for large model downloads
> ```

**Queue Manager API endpoints:**
- `POST /v1/chat/completions` - submit inference request (waits for result)
- `GET  /queue/status` - current mode, queue depth, node3 model, exo state
- `GET  /tasks/{task_id}` - poll individual task status

---

## 7.3 RAG - Knowledge-Enhanced AI (`services/rag/`)

Allows the AI to answer questions using your organization's own documents. **Port 8081** (internal) | **Port 8444** HTTPS (via Nginx, basic auth) | FastAPI + Qdrant + BAAI/bge-m3

```
WITHOUT RAG:
  User: "What is our data retention policy?"
  AI:   "Generally, data retention policies..."  ← Generic

WITH RAG:
  User: "What is our data retention policy?"
  AI:   "Based on 'IT Policy Manual 2025.pdf':
         Personal data deleted after 3 years..."  ← Accurate
```

### How It Works

```
INGEST (once per document):
  Upload PDF/DOCX/image/text
  → Extract text (+ table detection for PDF/DOCX)
  → OCR via Typhoon OCR 1.5 if text layer is absent or Thai ratio < 5%
  → Normalize Thai encoding (sara am, lookalike glyphs, spacing)
  → Split into 2,000-char chunks (200-char overlap)
  → Convert to vector (BAAI/bge-m3, 1024-dim)
  → Store in Qdrant ("documents" collection)

QUERY (every request, inside Gateway):
  User question → synonym-expanded variants (Thai)
  → Exact filename lookup first (if question names a file)
  → Semantic search: top-5 chunks, threshold 0.25
  → Inject into AI context → grounded answer
```

### Supported Formats

| Format | Extraction Method |
|--------|-------------------|
| PDF | PyMuPDF text + table extraction (→ Markdown); Typhoon OCR fallback for scanned pages |
| DOCX | python-docx paragraphs + table → Markdown |
| Images | Typhoon OCR 1.5 (`scb10x/typhoon-ocr1.5-2b`) |
| Plain text / code / MD / CSV / JSON / YAML / SH | Direct ingestion |

> **OCR Engine (current):** Typhoon OCR 1.5 - a 2B vision-language model by SCB 10X, fine-tuned for Thai + English document extraction. Runs locally on Apple MPS (Metal). Triggered automatically when a PDF has no extractable text layer or when Thai character density is below 5%.
>
> **Table extraction:** PDF tables are detected and converted to Markdown; HTML tables in OCR output are preserved as `<table>` blocks in the chunk.
>
> **Thai normalization:** sara am decomposition, glyph-lookalike correction, stray inter-character spaces, and number-separator spacing are all fixed before embedding.

Admin dashboard at `https://llm-01.local:8444/admin` - upload, delete, view chunks, test queries.

---

## 7.4 Privacy Filter - PII Scrubbing (`services/privacy/`)

Automatically detects and replaces personal data before it reaches the AI. Built into the Gateway using **Microsoft Presidio + spaCy**. A standalone HTTP endpoint also exists at `services/privacy/presidio-filter.py`.

### What Gets Scrubbed

| Data Type | Example Input | What AI Sees |
|-----------|--------------|--------------|
| Thai person name | "สมชาย มีสุข อนุมัติแล้ว" | "[PERSON] อนุมัติแล้ว" |
| Thai phone number | "081-234-5678" | "[PHONE_NUMBER]" |
| Email address | "somchai@company.com" | "[EMAIL_ADDRESS]" |
| Credit card | "4111-1111-1111-1111" | "[CREDIT_CARD]" |

### What Is NOT Scrubbed

| Data | Reason |
|------|--------|
| **IP addresses** | Required for network diagnostics and operational tasks |

---

## 7.5 Monitoring & Observability (`services/monitoring/`)

### Prometheus (Port 9090)

Snapshots all metrics every 15 seconds from all three nodes.

```
Per Node (mac-metrics-exporter, port 9101):
  CPU:    per-core usage % (psutil)
  GPU:    residency / utilization % (sudo powermetrics)
  RAM:    used GB, available GB, usage % (psutil)
  Power:  system draw (milliwatts, sudo powermetrics)

Per Node (inference-metrics-exporter, port 9102):
  AI:     active request count per node
          tokens/second per node

Per Node (node-exporter, port 9100):
  OS:     standard Linux/macOS node metrics
```

### Grafana (Port 3001)

Two pre-provisioned dashboards:
- `mac-cluster-dashboard` - CPU, GPU, RAM, power per node
- `inference-dashboard` - active requests, tokens/second

```
┌─────────────────────────────────────────────────────┐
│  CPU           GPU            RAM                   │
│  N1: 78%       N1: 42%        N1: 29/36 GB          │
│  N2: 45%       N2: 71%        N2: 32/36 GB          │
│  N3: 60%       N3: 55%        N3: 28/36 GB          │
│                                                     │
│  Power         Tokens/sec                           │
│  N1: 28W       (not currently showing)              │
│  N2: 31W                                            │
│  N3: 29W                                            │
└─────────────────────────────────────────────────────┘
```

> **Known issue:** The Tokens/sec panel in `inference-dashboard` is not currently displaying data.

**Auto-alerts:** NodeDown (1 min), CPU >95% (5 min), RAM >95% (5 min), Temperature >90°C (2 min)

---

## 7.6 Web UI (`services/webui/`)

Custom chat interface for the cluster. **React 19 + TypeScript + Tailwind CSS 4 + Vite | Express.js backend (port 8000) | Exposed via Nginx on port 443 HTTPS**

```
┌────────────────────────────────────────────────────────────────┐
│ ┌──────────┐  ┌──────────────────────────────────────────────┐ │
│ │ SIDEBAR  │  │              CHAT AREA                       │ │
│ │ + New    │  │  AI: Hello! How can I help today?            │ │
│ │   Chat   │  │                                              │ │
│ │ History: │  │  You: Analyze this error log...              │ │
│ │ > Chat 1 │  │                                              │ │
│ │ [Model ▼]│  │  [Type your message...]  [+] [Send]          │ │
│ └──────────┘  └──────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

Features: model selector (qwen2.5 / qwen3.6 / phi4 / deepseek), file upload (PDF only), chat history (persisted to disk per user), auto-resize input, responsive layout.

The Express backend proxies `/api/chat` to the AI Gateway at `:8082`, translating short model names to full model IDs.

**URL:** `https://llm-01.local` (port 443, basic auth required)

---

## 7.7 ChatOps - Discord Bot (`services/chatops/`)

Discord integration for remote cluster interaction. **Status: Implemented - awaiting production token configuration.**

**Commands (prefix `!llm`):**

| Command | Example | What It Does |
|---------|---------|--------------|
| `ask` | `!llm ask What is the server status?` | Forwards question to Gateway, returns AI answer |
| `status` | `!llm status` | Queries Queue Manager `/queue/status` |
| `models` | `!llm models` | Lists available models |

The bot calls `https://llm-01.local:8443` (AI Gateway) and `http://llm-01.local:8080` (Queue Manager). A LaunchAgent plist (`com.llm.discord-bot.plist`) is ready for deployment once `DISCORD_BOT_TOKEN` is set in the environment.

---

# 8. AI MODELS

## Node Assignment (Production)

```
NODE 1 (llm-01) - Primary + Services
  Phi-4 14B (phi4:14b-q5_K_M)
  Fast responses - shares node with all platform services
  Ollama: localhost:11434

NODE 2 (llm-02) - Dedicated Inference
  Qwen 2.5 32B (qwen2.5:32b-instruct-q4_K_M)
  Powerful reasoning - full node dedicated to AI
  Ollama: localhost:11434 (tunneled as Node 1 :11435)

NODE 3 (llm-03) - Dynamic Switching
  Qwen 2.5 32B ←→ DeepSeek Coder V2 33B (auto-switch)
  General tasks → Qwen 2.5 / Code tasks → DeepSeek Coder
  Ollama: localhost:11434 (tunneled as Node 1 :11436)

ALL NODES - Exo Distributed (on demand)
  mlx-community/Qwen3.6-35B-A3B-8bit
  65,536 token context - all 3 Macs as one system
  API: llm-01.local:5678
```

## Additional Models (Installed for Testing Only)

| Model | Node | Status |
|-------|------|--------|
| qwen3:4b-q4_K_M | llm-01 | Testing only |
| qwen3:8b-q4_K_M | llm-01 | Testing only |
| qwen3:14b-q4_K_M | llm-01 | Testing only |
| qwen3:30b-a3b-q4_K_M | llm-02 | Testing only |
| qwen3:32b-q4_K_M | llm-03 | Testing only |

## Quantization

| Format | Memory Used | Quality Retained | Used For |
|--------|-------------|-----------------|----------|
| q5_K_M | ~63% of full | ~97% | Node 1 - Phi-4 |
| q4_K_M | ~50% of full | ~95% | Nodes 2 & 3 - Qwen 2.5, DeepSeek |
| 8bit MLX | ~50% of full | ~97% | Exo - Qwen3.6 |

## Context Window

| Model | Max Tokens (theoretical) | Approx. Length (theoretical) |
|-------|------------------------|----------------|
| Phi-4 14B | 16,000 | ~12,000 words |
| Qwen 2.5 32B | 32,768 | ~24,000 words |
| DeepSeek Coder 33B | 16,000 | ~12,000 words |
| Qwen3.6-35B (Exo) | 65,536 | ~49,000 words (~100 pages) |

> These are the theoretical maximums from official model documentation. Actual usable context depends on Ollama's runtime configuration (`num_ctx`), available RAM, and model quantization. The Exo value of 65,536 is the only one explicitly configured in this cluster. Ollama models use their built-in default unless overridden.

## Performance Benchmarks (Test Models - Normal Questions)

These figures were measured on the M4 Max nodes using the Qwen3 test variants. Cold start = model not yet loaded in RAM; warm start = model already resident.

### Throughput (tokens/second)

| Model | Cold Start | Warm Start | Overall Avg |
|-------|----------:|----------:|------------:|
| qwen3:4b-q4_K_M | 67.45 | 83.00 | 75.23 |
| qwen3:8b-q4_K_M | 44.75 | 56.05 | 50.40 |
| qwen3:14b-q4_K_M | 26.95 | 34.40 | 30.68 |
| qwen3:30b-a3b-q4_K_M | 54.65 | 73.10 | **63.88** |
| qwen3:32b-q4_K_M | 5.20 | 7.45 | 6.33 |

> `qwen3:30b-a3b` uses a Mixture-of-Experts (MoE) architecture - only 3B parameters are active per token - which explains why it outperforms the denser 14B model in speed while having 30B total parameters.

### Response Time (seconds to complete)

| Model | Cold Start | Warm Start | Overall Avg |
|-------|----------:|----------:|------------:|
| qwen3:4b-q4_K_M | 24.15 | 21.75 | 22.95 |
| qwen3:8b-q4_K_M | 36.15 | 29.25 | 32.70 |
| qwen3:14b-q4_K_M | 65.30 | 50.15 | 57.73 |
| qwen3:30b-a3b-q4_K_M | 38.15 | 26.90 | **32.53** |
| qwen3:32b-q4_K_M | 358.20 | 225.60 | 291.90 |

---

# 9. SECURITY ARCHITECTURE

```
NETWORK PERIMETER
  ● Firewall on all nodes (macOS pf)
  ● Internal subnet: 192.168.10.0/24
  ● SSH: key-based only, max 3 attempts
  ● Cloud services disabled (iCloud, Siri, telemetry)
        │
TRANSPORT
  ● Nginx TLS/SSL - HTTPS on ports 443, 8443, 8444
  ● Rate limiting: 200 req/hour (API), 100 req/hour (Web UI)
        │
APPLICATION
  ● Basic auth on Web UI (port 443) and RAG Admin (port 8444)
  ● Optional API key validation on Gateway (port 8082/8443)
  ● PII scrubbing on all requests
  ● Full audit logging
        │
DATA
  ● No external transmission - ever
  ● Qdrant local on Node 1 (Docker)
  ● Secrets in .env - excluded from version control
```

**Enterprise hardening** (`scripts/hardening/enterprise-hardening.sh`):
Sleep disabled, firewall with logging, SSH hardened, iCloud/Siri/telemetry disabled, auto-updates enabled.

---

# 10. AUTOMATION CAPABILITIES

Three services run continuously on Node 1 via LaunchAgent:

## Log Analyzer (`services/automation/log-analyzer.py`)
**Schedule: Hourly** | **Model: phi4:latest via Gateway (localhost:8082)**

Watches `/var/log/nginx/error.log` and `/tmp/queue-manager.err` → submits last 50 lines to phi4 → identifies errors, warnings, root causes → saves to `logs/analysis/YYYYMMDD_HHMMSS.md`

## Report Generator (`services/automation/report-generator.py`)
**Schedule: Daily** | **Model: phi4:14b-q5_K_M direct on llm-01.local:11434 (Ollama API)**

Produces a cluster health report: current date/time, queue status, disk info. Saves to `logs/reports/`.

## Code Reviewer (`services/automation/code-reviewer.py`)
**On demand** | **Model: deepseek-coder-v2:33b-instruct-q4_K_M direct on llm-01.local:11434** | 120s timeout

Reviews a submitted file path or git diff. Output: security issues, logic errors, style notes, quality rating.

---

# 11. DEPLOYMENT PROCESS

## Master Deployment (`scripts/deploy/deploy-all-nodes.sh`) - 8 Phases

```
Phase 1  SSH Key Distribution       Passwordless SSH across all nodes
Phase 2  Node Bootstrap             Homebrew, hardening, repo sync
Phase 3  Monitoring Stack           Node Exporter, Mac Exporter,
                                    Prometheus, Grafana
Phase 4  Docker                     Container runtime (for Qdrant)
Phase 5  Ollama & Models            Install Ollama, pull model files
Phase 6  Exo Distributed            Build from source (MLX backend)
Phase 7  Node 1 Services            Nginx, SSL, Qdrant, Web UI,
                                    Gateway, RAG
Phase 8  Queue & Validation         Start Queue Manager, LaunchAgents,
                                    health checks
```

## LaunchAgent Services (Auto-Start on Boot, Node 1)

| Service | Internal Port | Purpose |
|---------|--------------|---------|
| ai-gateway | 8082 | Main API entry point |
| litellm-proxy | 8083 | Multi-model Ollama adapter |
| queue-manager | 8080 | Model routing & node3 switching |
| rag-server | 8081 | RAG + document ingestion |
| ollama | 11434 | AI model inference (Node 1) |
| exo | 5678 | Distributed inference coordinator |
| qdrant (Docker) | 6333 | Vector database |
| grafana | 3001 | Dashboards |
| log-analyzer | - | Hourly automation |
| report-generator | - | Daily automation |
| inference-metrics-exporter | 9102 | AI throughput metrics |
| mac-metrics-exporter | 9101 | GPU/RAM/power metrics |
| ssh-tunnel-llm02 | - | localhost:11435 → llm-02:11434 |
| ssh-tunnel-llm03 | - | localhost:11436 → llm-03:11434 |
| discord-bot | - | ChatOps (pending token config) |

---

# 12. NETWORK & PORT REFERENCE

## Topology

```
Switch:   TP-LINK SX3008F (8-port 10 GbE)
Subnet:   192.168.10.0/24

llm-01.local  192.168.10.11  (Primary - all platform services)
llm-02.local  192.168.10.12  (Inference - Qwen 2.5 32B)
llm-03.local  192.168.10.13  (Dynamic - Qwen 2.5 / DeepSeek Coder)
```

## 10 Gigabit Ethernet

| Metric | Value |
|--------|-------|
| Link speed | 10 Gbps (10× standard office) |
| MTU | 9,000 bytes (jumbo frames) |
| Benefit | Low overhead for large model data transfers |

## Port Reference

### External Ports (Nginx on Node 1 - accessible from network)

| Port | Protocol | Auth | Service | Notes |
|------|----------|------|---------|-------|
| **80** | HTTP | - | Nginx | Redirects to 443 |
| **443** | HTTPS | Basic auth | Web UI | React frontend + `/api/` → Express :8000 |
| **3001** | HTTP | - | Grafana | Dashboard proxy |
| **8443** | HTTPS | API key (optional) | AI Gateway | `/v1/` → :8082, `/litellm/` → :8083; 200 req/h |
| **8444** | HTTPS | Basic auth | RAG Admin | `/admin` dashboard, upload, search → :8081 |

### Node 1 Internal Services (not directly externally exposed)

| Port | Service | Notes |
|------|---------|-------|
| **3000** | Web UI React (Vite) | Proxied via Nginx :443 |
| **5678** | Exo coordinator | Distributed inference; all 3 nodes connect here |
| **6333** | Qdrant (Docker) | Vector DB; used by RAG server and Gateway |
| **8000** | Web UI Express backend | Chat proxy to Gateway :8082 |
| **8080** | Queue Manager | Model routing, node3 switching, Exo lifecycle |
| **8081** | RAG Server | Document ingestion + semantic search |
| **8082** | AI Gateway | PII + RAG + semaphore + routing |
| **8083** | LiteLLM proxy | Ollama adapter with auth; master key `sk-llm-cluster` |
| **9090** | Prometheus | Metrics collection (all nodes, 15s scrape) |
| **9101** | Mac metrics exporter | GPU/CPU/RAM/power (Node 1) |
| **9102** | Inference metrics exporter | tok/s, active requests (Node 1) |

### Inference Ports (All Nodes)

| Port | Service | Node(s) |
|------|---------|---------|
| **11434** | Ollama (native) | llm-01, llm-02, llm-03 |
| **11435** | SSH tunnel → llm-02:11434 | Node 1 view of Node 2 Ollama |
| **11436** | SSH tunnel → llm-03:11434 | Node 1 view of Node 3 Ollama |
| **5678** | Exo worker | llm-02, llm-03 (connect to llm-01 coordinator) |

### Monitoring Ports (All Nodes)

| Port | Service |
|------|---------|
| **9100** | Node Exporter |
| **9101** | Mac metrics exporter |
| **9102** | Inference metrics exporter |

## SSH Tunnels (Node 1 Local Port Forwarding)

Maintained by LaunchAgents - auto-reconnect on drop.

```
localhost:11435  ──SSH──▶  llm-02 (192.168.10.12) :11434  [Qwen 2.5 32B]
localhost:11436  ──SSH──▶  llm-03 (192.168.10.13) :11434  [Qwen 2.5 32B / DeepSeek Coder]
```

Both the LiteLLM proxy and the Queue Manager on Node 1 reach remote Ollama instances through these tunnels. The Gateway enforces a **1-concurrent-request semaphore per node** before routing through LiteLLM.

---

# 13. USE CASES

**Internal AI Assistant** - Team members query the Web UI in natural language; RAG enriches answers with internal documents.

**Document Intelligence** - Upload policies, manuals, and reports. The AI cites the exact source document when answering.

**Automated Log Analysis** - Hourly summaries identify critical issues across all nodes without manual review.

**Code Review Assistance** - Developers submit code/diffs for AI review before human review; common issues caught automatically.

**Daily Infrastructure Reports** - Management-ready health reports generated automatically every morning.

**Distributed Large-Context Inference (Exo)** - All three Macs united for analyzing large codebases, lengthy legal documents, or multi-hundred-page reports (65,536-token context).

**ChatOps (Discord)** - Query the cluster, check status, and list models directly from a Discord channel using `!llm` commands.

---

# 14. BENEFITS SUMMARY

## Fully Open-Source - Zero Licensing Cost

| Component | License | Cost |
|-----------|---------|------|
| Ollama, Exo, Qdrant, Prometheus, Grafana, LiteLLM, Presidio, FastAPI, React, all AI models | MIT / Apache 2.0 / open weights | **Free** |

No per-query costs. No subscriptions. No license fees. Only ongoing cost: electricity (~100W per node at peak load).

## Comparison

| Dimension | Cloud AI Service | This Platform |
|-----------|-----------------|---------------|
| Data leaves premises | Yes | **No** |
| Per-query cost | Yes | **No** |
| Internet required | Yes | **No** |
| Model selection | Vendor only | Any open model |
| Configuration control | Limited | Full |
| Privacy compliance | Requires agreements | Built in by architecture |

---

# 15. TECHNICAL REFERENCE

## Full Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| AI Runtime | Ollama | Latest |
| Distributed AI | Exo (MLX backend) | Latest - built from source |
| API Framework | FastAPI + uvicorn | Latest |
| Load Balancer | LiteLLM | Port 8083, latency-based routing |
| Vector DB | Qdrant | Latest - Docker on Node 1 |
| Embeddings | BAAI/bge-m3 | 1024-dim cosine similarity |
| PII Detection | Microsoft Presidio + spaCy | Built into Gateway |
| OCR Engine | Typhoon OCR 1.5 (`scb10x/typhoon-ocr1.5-2b`) | Vision-LM, Thai + English |
| Thai Synonyms | `thai_synonyms.py` (custom) | Expands RAG queries |
| Reverse Proxy | Nginx | Latest - Homebrew on Node 1 |
| Metrics | Prometheus | Latest |
| Dashboards | Grafana | Latest |
| Frontend | React 19 + TypeScript | 19.2 |
| Styling | Tailwind CSS | 4.3 |
| Build Tool | Vite | 8 |
| Backend Proxy | Express.js | 4.18 |
| PDF Processing | PyMuPDF (fitz) | Latest |
| DOCX Processing | python-docx | Latest |
| Containers | Docker | Latest - Qdrant only |
| Service Manager | macOS LaunchAgent | Auto-start + crash-restart |
| Network Switch | TP-LINK SX3008F | 8-port 10 GbE |

## Repository Structure

```
mac-llm-cluster/
├── config/         Nginx, Prometheus, Grafana, Exo, SSH,
│   ├── launchd/    LaunchAgent plists (all services)
│   ├── nginx/      conf.d: gateway, webui, monitoring, rag-admin
│   ├── ollama/     Per-node model lists (node1/2/3-models.txt)
│   └── ...         cluster.conf, prometheus, grafana, secrets
├── scripts/        Shell scripts
│   ├── deploy/     Cluster orchestration (8 phases)
│   ├── exo/        Distributed inference setup + restart
│   ├── hardening/  Security configuration
│   ├── monitoring/ Stack installation
│   ├── network/    10GbE / mDNS setup
│   ├── nginx/      SSL generation, user creation
│   └── health/     Service health checks
├── services/       Microservices (Python + Node.js)
│   ├── ai-gateway/ FastAPI gateway (PII + RAG + semaphore + routing)
│   │   ├── gateway.py          Main entry point
│   │   ├── litellm_config.yaml LiteLLM model → Ollama mapping
│   │   └── thai_synonyms.py    RAG query expansion
│   ├── queue/      Intelligent model routing manager
│   │   ├── intelligent-queue-manager.py  Queue + node3 switching
│   │   └── exo-controller.py             Exo load/unload CLI
│   ├── rag/        RAG server + Qdrant document ingestion
│   │   └── qdrant-rag-server.py  Upload, search, admin UI
│   ├── privacy/    Standalone PII filter endpoint
│   ├── monitoring/ Custom metric exporters (mac + inference)
│   ├── automation/ Log analyzer, report generator, code reviewer
│   ├── chatops/    Discord bot + Slack bot
│   └── webui/      React frontend + Express backend
│       ├── frontend/   Vite/React app (port 3000)
│       └── backend/    Express proxy (port 8000)
├── tests/          Validation and stress test scripts
├── logs/           Analysis output, audit logs, reports
├── backups/        Configuration backups
└── docs/           Documentation
```

---

# 16. PLANNED UPGRADES

| Feature | Description | Status |
|---------|-------------|--------|
| **Discord Bot** | ChatOps: `!llm ask`, `!llm status`, `!llm models` | Implemented - pending token config |
| **Slack Bot** | Same ChatOps via Slack (`services/chatops/slack-bot.py`) | Implemented - pending deployment |
| **Improved Thai OCR** | Upgraded from Tesseract to Typhoon OCR 1.5 | **Done** |

---

# 17. GLOSSARY

| Term | Plain English |
|------|--------------|
| **LLM** | Large Language Model - AI that understands and generates text |
| **Ollama** | Open-source tool that runs AI models locally |
| **Exo** | Open-source tool that splits one AI model across multiple computers |
| **RAG** | Method for AI to answer using your own uploaded documents |
| **Qdrant** | Database storing text as vectors for fast semantic search |
| **Vector** | Numbers representing the meaning of a piece of text |
| **Quantization** | Compressing an AI model to use less RAM with minimal quality loss |
| **Token** | A word or word-fragment - roughly 0.75 words on average |
| **Context Window** | Maximum text the AI can read and reason about in one request |
| **Prometheus** | Collects system measurements over time |
| **Grafana** | Visualizes Prometheus data as interactive dashboards |
| **LaunchAgent** | macOS mechanism to auto-start a service and restart it on crash |
| **API** | Standardized way for software programs to communicate |
| **FastAPI** | Python framework for building fast web APIs |
| **Nginx** | Web server used here as reverse proxy and SSL terminator |
| **LiteLLM** | Proxy that gives multiple Ollama instances a unified OpenAI-compatible API |
| **PII** | Personally Identifiable Information - data that can identify a real person |
| **Presidio** | Microsoft's open-source PII detection and anonymization library |
| **Semaphore** | Concurrency control: limits to 1 active inference job per node |
| **MTU 9000** | Jumbo frame size - reduces network overhead on 10GbE |
| **mDNS** | Protocol for devices to find each other by name on a local network |
| **SSH Tunnel** | Encrypted private connection that forwards a local port to a remote service |
| **Docker** | Container platform for isolated application environments |
| **Unified Memory** | Apple Silicon: CPU and GPU share the same RAM pool |
| **Typhoon OCR** | Thai-English vision-language OCR model by SCB 10X |
| **BAAI/bge-m3** | Multilingual embedding model used to convert text to semantic vectors |
| **ChatOps** | Using a chat platform (Discord/Slack) to trigger and monitor operations |

---

*Classification: Internal Use*
*Hardware: 3× Apple Mac Studio M4 Max - 36 GB RAM / 512 GB SSD each*
*Network: TP-LINK SX3008F 10 GbE - 192.168.10.0/24*
*Software Stack: Fully open-source*
*Last updated: June 2026*
