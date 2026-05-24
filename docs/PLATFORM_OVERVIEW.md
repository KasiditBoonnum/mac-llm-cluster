# MAC LLM CLUSTER & AI GATEWAY
## Platform Technical Overview

---

# TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Why We Built This](#why-we-built-this)
3. [What Is an LLM?](#what-is-an-llm)
4. [System Architecture — The Big Picture](#system-architecture)
5. [Hardware: 3× Mac Studio M4 Max](#hardware)
6. [Request Flow — End to End](#request-flow)
7. [Core Components](#core-components)
8. [AI Models](#ai-models)
9. [Security Architecture](#security-architecture)
10. [Automation Capabilities](#automation-capabilities)
11. [Deployment Process](#deployment-process)
12. [Network Architecture](#network-architecture)
13. [Use Cases](#use-cases)
14. [Benefits Summary](#benefits-summary)
15. [Technical Reference](#technical-reference)
16. [Planned Upgrades](#planned-upgrades)
17. [Glossary](#glossary)

---

# 1. EXECUTIVE SUMMARY

The **MAC LLM CLUSTER & AI GATEWAY** is an on-premise (self-hosted) artificial intelligence platform built on three Apple Mac Studio computers. It allows an organization to run powerful, state-of-the-art large language models — the same category of AI that powers modern AI assistants — entirely within its own network, without sending any data to external cloud services.

**Three core goals drive this project:**

| Goal | What It Means |
|------|---------------|
| **Development & Testing** | Run and experiment with LLM models in-house, reducing cloud dependency |
| **Data Privacy** | All data stays on organization hardware — nothing leaves the local network |
| **Automation** | Power internal tools: log analysis, automated reporting, AI-assisted workflows |

**In short:** A private, fully open-source AI platform running on your own hardware — completely under your control, with no per-query costs and no external data transmission.

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
- No data leaves the building — full privacy by architecture
- No recurring API fees — hardware is a one-time investment, all software is open-source
- No internet dependency — works when external connectivity is unavailable
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

## Models We Run

| Model | Parameters | Best For |
|-------|-----------|----------|
| **Phi-4** (14B) | 14 billion | Fast responses, general tasks |
| **Qwen 2.5** (32B) | 32 billion | Complex reasoning and analysis |
| **DeepSeek Coder V2** (33B) | 33 billion | Code writing and review |
| **Qwen3.6-35B** (distributed) | 35 billion | Maximum capability, long documents |

> **What does "B" mean?**
> Parameters are the learned values inside the model — roughly analogous to knowledge capacity. More parameters = more capability, but also requires more RAM and compute.

---

# 4. SYSTEM ARCHITECTURE — THE BIG PICTURE

```
╔══════════════════════════════════════════════════════════════════╗
║                    MAC LLM CLUSTER PLATFORM                      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  USERS                    GATEWAY LAYER               AI LAYER  ║
║  ┌─────────┐   HTTPS     ┌──────────────┐           ┌────────┐  ║
║  │  Chat   │────────────▶│  AI Gateway  │──────────▶│ Node 1 │  ║
║  │  Web UI │             │  (Port 8082) │           │ Phi-4  │  ║
║  └─────────┘             │              │           └────────┘  ║
║  ┌─────────┐             │  ✓ Privacy   │           ┌────────┐  ║
║  │ Scripts │────────────▶│  ✓ RAG       │──────────▶│ Node 2 │  ║
║  │  / API  │             │  ✓ Load Bal  │           │Qwen2.5 │  ║
║  └─────────┘             └──────────────┘           └────────┘  ║
║                          ┌──────────────┐           ┌────────┐  ║
║                          │Queue Manager │──────────▶│ Node 3 │  ║
║                          │  (Port 8080) │           │Dynamic │  ║
║                          └──────────────┘           └────────┘  ║
║                                                                  ║
║  KNOWLEDGE BASE           MONITORING                            ║
║  ┌──────────────┐         ┌──────────────────────────────────┐  ║
║  │  RAG Server  │         │ Prometheus (metrics) + Grafana   │  ║
║  │  (Port 8081) │         │        (dashboards)              │  ║
║  │  Qdrant DB   │         └──────────────────────────────────┘  ║
║  └──────────────┘                                               ║
╚══════════════════════════════════════════════════════════════════╝
```

---

# 5. HARDWARE: 3× MAC STUDIO M4 MAX

## Physical Setup

```
  ┌────────────────────────────────────────────────────────────┐
  │        TP-LINK SX3008F — 10 Gigabit Ethernet Switch        │
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
  │ Gateway    │        │ Qwen2.5    │     │ Qwen2.5    │
  │ Queue      │        │ (32B)      │     │   ↕ auto   │
  │ RAG DB     │        │            │     │ DeepSeek   │
  │ Web UI     │        │            │     │ Coder (33B)│
  │ Nginx      │        │            │     │            │
  │ Prometheus │        │            │     │            │
  │ Phi-4 (14B)│        │            │     │            │
  └────────────┘        └────────────┘     └────────────┘
```

## Why Mac Studio M4 Max for AI?

| Feature | Advantage for AI |
|---------|-----------------|
| **Unified Memory** | CPU and GPU share the same 36 GB RAM — a 30B+ model fits in one machine |
| **Apple Neural Engine** | Dedicated on-chip AI acceleration hardware |
| **Memory Bandwidth** | ~400 GB/s — critical for fast model weight access |
| **Energy Efficiency** | ~30W per node at load |
| **Form Factor** | Compact — fits in an office or equipment room |

## Cluster Totals

| Resource | Per Node | Total (3 Nodes) |
|----------|----------|-----------------|
| RAM | 36 GB | **108 GB** |
| Storage | 512 GB | **1.5 TB** |
| Chip | M4 Max | 3× M4 Max |

All nodes communicate over **SSH** through the SX3008F 10GbE switch — required by macOS network access policies.

---

# 6. REQUEST FLOW — END TO END

```
Step 1: User sends a message
        "What were the top 5 errors in the logs last week?"

Step 2: PII Filter scans for sensitive personal data
        "สมชาย มีสุข" → [PERSON]
        "081-234-5678" → [PHONE_NUMBER]
        "192.168.10.50" → kept (IPs are not scrubbed)

Step 3: RAG retrieves relevant documents from Qdrant
        Found: "Server Incident Report Q1-2026.pdf"
        Found: "Error Handling Runbook v3.docx"
        → chunks injected into the prompt as context

Step 4: Queue Manager selects the best available node
        Node 1: 1 active request
        Node 2: free → routed here

Step 5: AI generates response (Node 2, Qwen 2.5 32B)

Step 6: Response returned to user
        "The top 5 errors last week were:
         1. Disk full on Node 3 (12 occurrences)..."
```

---

# 7. CORE COMPONENTS

## 7.1 AI Gateway (`services/ai-gateway/`)

Single entry point for all requests. **Port 8082** | Python FastAPI

```
REQUESTS ────────▶  AI GATEWAY
                    ├─ 1. Optional API key validation
                    ├─ 2. PII scan & selective scrubbing
                    ├─ 3. RAG document retrieval (Qdrant)
                    ├─ 4. Route to LiteLLM proxy (8083)
                    └─ 5. Return response + log pipeline
```

**OpenAI API compatibility:** Any application already calling an OpenAI-compatible endpoint can redirect to this cluster by changing only the base URL — no code changes needed.

---

## 7.2 Intelligent Queue Manager (`services/queue/`)

Traffic controller for model routing and resource management. **Port 8080** | Python FastAPI

### Dynamic Model Switching (Node 3)

```
Node 3 running: Qwen 2.5 32B (general purpose)
    │
    ▼ Code task detected
    │
Unload Qwen 2.5 → Load DeepSeek Coder V2 33B (~2–3 min)
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
                                        ║ 65,536 ctx tokens ║
                                        ╚══════════════════╝
```

5-minute idle timeout: Exo unloads to free resources.

SSH tunnels reach Node 2 and Node 3 Ollama instances (ports 11435–11437).

---

## 7.3 RAG — Knowledge-Enhanced AI (`services/rag/`)

Allows the AI to answer questions using your organization's own documents. **Port 8081** | FastAPI + Qdrant + BAAI/bge-m3

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
  Upload PDF/DOCX
  → Extract text + detect tables
  → Split into 800-char chunks (100-char overlap)
  → Convert to vector (BAAI/bge-m3)
  → Store in Qdrant

QUERY (every request):
  User question → convert to vector
  → Find top matching chunks (threshold: 0.45)
  → Inject into AI context → grounded answer
```

### Supported Formats

| Format | Notes |
|--------|-------|
| PDF | Text + table extraction (→ Markdown) |
| DOCX | Microsoft Word |
| Images | OCR via **Tesseract** (`pytesseract`) — digital text reliable; Thai scanned text has partial support |
| Plain text / code | Direct ingestion |

> **OCR Engine:** Tesseract with `tha+eng` language pack (Thai + English), `--psm 3` (automatic page segmentation), `--oem 1` (LSTM neural network mode). Image rendering uses Pillow (PIL).
>
> **Thai OCR:** Digitally-created Thai PDFs work reliably. Scanned Thai documents may not extract correctly in all cases due to font and encoding variability.

Admin dashboard at `/dashboard` for upload, delete, stats, and test queries.

---

## 7.4 Privacy Filter — PII Scrubbing (`services/privacy/`)

Automatically detects and replaces personal data before it reaches the AI. **Microsoft Presidio + spaCy**

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
Per Node:
  CPU:    per-core usage (%)
  GPU:    residency / utilization (%)
  RAM:    used GB, available GB, usage %
  Power:  system draw (milliwatts)
  AI:     active request count, tokens/second
```

### Grafana (Port 3001)

Two pre-provisioned dashboards:
- `mac-cluster-dashboard` — CPU, GPU, RAM, power per node
- `inference-dashboard` — active requests, tokens/second

```
┌─────────────────────────────────────────────────────┐
│  CPU           GPU            RAM                   │
│  N1: 78%       N1: 42%        N1: 29/36 GB          │
│  N2: 45%       N2: 71%        N2: 32/36 GB          │
│  N3: 60%       N3: 55%        N3: 28/36 GB          │
│                                                     │
│  Power         Tokens/sec                           │
│  N1: 28W       Total: 47 tok/s                      │
│  N2: 31W       N2: 29 tok/s                         │
│  N3: 29W       N3: 18 tok/s                         │
└─────────────────────────────────────────────────────┘
```

**Auto-alerts:** NodeDown, CPU >95%, RAM >95%

---

## 7.6 Web UI (`services/webui/`)

Custom chat interface for the cluster. **React 19 + TypeScript + Tailwind CSS 4 + Vite | Express.js backend**

```
┌────────────────────────────────────────────────────────────────┐
│ ┌──────────┐  ┌──────────────────────────────────────────────┐ │
│ │ SIDEBAR  │  │              CHAT AREA                       │ │
│ │ + New    │  │  AI: Hello! How can I help today?            │ │
│ │   Chat   │  │                                              │ │
│ │ History: │  │  You: Analyze this error log...              │ │
│ │ > Chat 1 │  │                                              │ │
│ │ [Model ▼]│  │  [Type your message...]  [📎] [Send]         │ │
│ └──────────┘  └──────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

Features: model selector, file upload, chat history, auto-resize input, responsive layout.

---

# 8. AI MODELS

## Node Assignment

```
NODE 1 (llm-01) — Primary + Services
  Phi-4 14B (q5_K_M)
  Fast responses — shares node with all platform services

NODE 2 (llm-02) — Dedicated Inference
  Qwen 2.5 32B (q4_K_M)
  Powerful reasoning — full node dedicated to AI

NODE 3 (llm-03) — Dynamic Switching
  Qwen 2.5 32B ←→ DeepSeek Coder V2 33B (auto-switch)
  General tasks → Qwen 2.5 / Code tasks → DeepSeek Coder

ALL NODES — Exo Distributed (on demand)
  mlx-community/Qwen3.6-35B-A3B-8bit
  65,536 token context — all 3 Macs as one system
```

## Quantization

| Format | Memory Used | Quality Retained | Used For |
|--------|-------------|-----------------|----------|
| q5_K_M | ~63% of full | ~97% | Node 1 — Phi-4 |
| q4_K_M | ~50% of full | ~95% | Nodes 2 & 3 |
| 8bit | ~50% of full | ~97% | Exo — Qwen3.6 |

## Context Window

| Model | Tokens | Approx. Length |
|-------|--------|----------------|
| Phi-4 14B | 16,384 | ~12,000 words |
| Qwen 2.5 32B | 32,768 | ~24,000 words |
| DeepSeek Coder V2 33B | 32,768 | ~24,000 words |
| Qwen3.6-35B (Exo) | **65,536** | ~49,000 words (~100 pages) |

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
  ● Nginx TLS/SSL (HTTPS port 8443)
  ● Rate limiting: 200 req/hour, burst 50
        │
APPLICATION
  ● Optional API key validation
  ● PII scrubbing on all requests
  ● Full audit logging
        │
DATA
  ● No external transmission — ever
  ● Qdrant local on Node 1 (Docker)
  ● Secrets in .env — excluded from version control
```

**Enterprise hardening** (`scripts/hardening/enterprise-hardening.sh`):
Sleep disabled, firewall with logging, SSH hardened, iCloud/Siri/telemetry disabled, auto-updates enabled.

---

# 10. AUTOMATION CAPABILITIES

Three services run continuously on Node 1 via LaunchAgent:

## Log Analyzer (`services/automation/log-analyzer.py`)
**Schedule: Hourly**
Reads service logs from all nodes → submits to local AI → identifies errors, warnings, root causes → saves to `logs/analysis/YYYY-MM-DD-HH.md`

## Report Generator (`services/automation/report-generator.py`)
**Schedule: Daily**
Produces a cluster health report: uptime, request totals, model usage, error rates, performance trends.

## Code Reviewer (`services/automation/code-reviewer.py`)
Uses DeepSeek Coder V2 (33B) to review a submitted file or git diff.
Output: security issues, logic errors, style notes, quality rating.

---

# 11. DEPLOYMENT PROCESS

## Master Deployment (`scripts/deploy/deploy-all-nodes.sh`) — 8 Phases

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

## LaunchAgent Services (Auto-Start on Boot)

| Service | Port | Purpose |
|---------|------|---------|
| ai-gateway | 8082 | Main API entry point |
| litellm-proxy | 8083 | Multi-model load balancing |
| queue-manager | 8080 | Model routing & switching |
| ollama | 11434 | AI model inference |
| exo | 5678 | Distributed inference |
| qdrant (Docker) | 6333 | Vector database |
| grafana | 3001 | Dashboards |
| log-analyzer | — | Hourly automation |
| report-generator | — | Daily automation |
| inference-metrics-exporter | 9102 | AI throughput metrics |
| mac-metrics-exporter | 9101 | GPU/RAM/power metrics |
| ssh-tunnel-llm02 | — | Tunnel to Node 2 |
| ssh-tunnel-llm03 | — | Tunnel to Node 3 |

---

# 12. NETWORK ARCHITECTURE

## Topology

```
Switch:   TP-LINK SX3008F (8-port 10 GbE)
Subnet:   192.168.10.0/24

llm-01.local  192.168.10.x  (Primary)
llm-02.local  192.168.10.x  (Inference)
llm-03.local  192.168.10.x  (Dynamic)
```

## 10 Gigabit Ethernet

| Metric | Value |
|--------|-------|
| Link speed | 10 Gbps (10× standard office) |
| MTU | 9,000 bytes (jumbo frames) |
| Benefit | Low overhead for large model data transfers |

## Port Reference

```
EXTERNAL (Nginx on Node 1):  8443 HTTPS · 3000 Web UI · 3001 Grafana · 9090 Prometheus
NODE 1 INTERNAL:             8082 Gateway · 8083 LiteLLM · 8080 Queue · 8081 RAG · 6333 Qdrant
INFERENCE (SSH tunnel):      11434 Ollama N1&N2 · 11435 Ollama N3 · 5678 Exo
MONITORING (all nodes):      9100 Node Exporter · 9101 Mac Exporter · 9102 Inference Exporter
```

## SSH Tunnels

```
Node 1 (Queue Manager)
  ├── SSH tunnel → port 11436 → Node 2 Ollama (11434)
  └── SSH tunnel → port 11437 → Node 3 Ollama (11435)

Maintained by LaunchAgents — auto-reconnect on drop.
```

---

# 13. USE CASES

**Internal AI Assistant** — Team members query the Web UI in natural language; RAG enriches answers with internal documents.

**Document Intelligence** — Upload policies, manuals, and reports. The AI cites the exact source document when answering.

**Automated Log Analysis** — Hourly summaries identify critical issues across all nodes without manual review.

**Code Review Assistance** — Developers submit code/diffs for AI review before human review; common issues caught automatically.

**Daily Infrastructure Reports** — Management-ready health reports generated automatically every morning.

**Distributed Large-Context Inference (Exo)** — All three Macs united for analyzing large codebases, lengthy legal documents, or multi-hundred-page reports (65,536-token context).

---

# 14. BENEFITS SUMMARY

## Fully Open-Source — Zero Licensing Cost

| Component | License | Cost |
|-----------|---------|------|
| Ollama, Exo, Qdrant, Prometheus, Grafana, LiteLLM, Presidio, FastAPI, React, all AI models | MIT / Apache 2.0 / open weights | **Free** |

No per-query costs. No subscriptions. No license fees. Only ongoing cost: electricity (~30 W per node).

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

| Layer | Technology | Version |
|-------|-----------|---------|
| AI Runtime | Ollama | Latest |
| Distributed AI | Exo (MLX backend) | Latest |
| API Framework | FastAPI | Latest |
| Load Balancer | LiteLLM | Latest |
| Vector DB | Qdrant | Latest |
| Embeddings | BAAI/bge-m3 | Latest |
| PII Detection | Presidio + spaCy | Latest |
| Reverse Proxy | Nginx | Latest |
| Metrics | Prometheus | Latest |
| Dashboards | Grafana | Latest |
| Frontend | React 19 + TypeScript | 19.2 / 6 |
| Styling | Tailwind CSS | 4.3 |
| Build Tool | Vite | 8 |
| Backend Proxy | Express | 4.18 |
| Containers | Docker | Latest |
| Service Manager | macOS LaunchAgent | — |
| PDF Processing | PyMuPDF | Latest |
| OCR Engine | Tesseract (via pytesseract) | Latest | Image text extraction (`tha+eng`, LSTM) |
| Network Switch | TP-LINK SX3008F | — |

## Repository Structure

```
mac-llm-cluster/
├── config/         Nginx, Prometheus, Grafana, Exo, SSH,
│                   launchd, Ollama per-node model lists
├── scripts/        100+ shell scripts
│   ├── deploy/     Cluster orchestration (8 phases)
│   ├── ollama/     Model management
│   ├── exo/        Distributed inference setup
│   ├── monitoring/ Stack installation
│   ├── hardening/  Security configuration
│   ├── network/    10GbE / mDNS setup
│   └── health/     Service health checks
├── services/       Microservices
│   ├── ai-gateway/ FastAPI gateway (PII + RAG + routing)
│   ├── queue/      Intelligent model routing manager
│   ├── rag/        RAG server + Qdrant document ingestion
│   ├── privacy/    Standalone PII filter endpoint
│   ├── monitoring/ Custom metric exporters
│   ├── automation/ Log analyzer, reports, code reviewer
│   └── webui/      React frontend + Express backend
├── tests/          Validation and stress test scripts
├── logs/           Analysis output, audit logs
├── backups/        Configuration backups
└── docs/           Documentation
```

---

# 16. PLANNED UPGRADES

| Feature | Description | Status |
|---------|-------------|--------|
| **Discord Bot** | ChatOps: `!ask`, `!status`, `!models` | Planned |
| **Slack Bot** | Same ChatOps via Slack | Planned |
| **Improved Thai OCR** | Better scanned Thai document extraction | Planned |

---

# 17. GLOSSARY

| Term | Plain English |
|------|--------------|
| **LLM** | Large Language Model — AI that understands and generates text |
| **Ollama** | Open-source tool that runs AI models locally |
| **Exo** | Open-source tool that splits one AI model across multiple computers |
| **RAG** | Method for AI to answer using your own uploaded documents |
| **Qdrant** | Database storing text as vectors for fast semantic search |
| **Vector** | Numbers representing the meaning of a piece of text |
| **Quantization** | Compressing an AI model to use less RAM with minimal quality loss |
| **Token** | A word or word-fragment — roughly 0.75 words on average |
| **Context Window** | Maximum text the AI can read and reason about in one request |
| **Prometheus** | Collects system measurements over time |
| **Grafana** | Visualizes Prometheus data as interactive dashboards |
| **LaunchAgent** | macOS mechanism to auto-start a service and restart it on crash |
| **API** | Standardized way for software programs to communicate |
| **FastAPI** | Python framework for building fast web APIs |
| **Nginx** | Web server used here as reverse proxy and SSL terminator |
| **PII** | Personally Identifiable Information — data that can identify a real person |
| **MTU 9000** | Jumbo frame size — reduces network overhead on 10GbE |
| **mDNS** | Protocol for devices to find each other by name on a local network |
| **SSH Tunnel** | Encrypted private connection between two computers |
| **Docker** | Container platform for isolated application environments |
| **Unified Memory** | Apple Silicon: CPU and GPU share the same RAM pool |

---

*Classification: Internal Use*
*Hardware: 3× Apple Mac Studio M4 Max — 36 GB RAM / 512 GB SSD each*
*Network: TP-LINK SX3008F 10 GbE — 192.168.10.0/24*
*Software Stack: Fully open-source*
