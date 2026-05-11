#!/bin/bash
# Full cluster health check

echo "╔══════════════════════════════════════╗"
echo "║     LLM Cluster Health Check        ║"
echo "╚══════════════════════════════════════╝"
echo ""

check_service() {
    local name=$1
    local url=$2
    if curl -s --max-time 3 "$url" &>/dev/null; then
        echo "  ✅ $name"
    else
        echo "  ❌ $name ($url)"
    fi
}

echo "── Ollama ──────────────────────────────"
check_service "Node 1 Ollama (:11434)" "http://llm-01.local:11434/api/tags"
check_service "Node 2 Ollama (:11434)" "http://llm-02.local:11434/api/tags"
check_service "Node 3 Ollama (:11435)" "http://llm-03.local:11435/api/tags"

echo ""
echo "── Monitoring ──────────────────────────"
check_service "Node Exporter (llm-01)" "http://llm-01.local:9100/metrics"
check_service "Node Exporter (llm-02)" "http://llm-02.local:9100/metrics"
check_service "Node Exporter (llm-03)" "http://llm-03.local:9100/metrics"
check_service "Mac Exporter  (llm-01)" "http://llm-01.local:9101/metrics"
check_service "Prometheus"             "http://llm-01.local:9090/-/healthy"
check_service "Grafana"               "http://llm-01.local:3001/api/health"

echo ""
echo "── Services (Node 1) ───────────────────"
check_service "Queue Manager"   "http://llm-01.local:8080/health"
check_service "Web UI"         "http://llm-01.local:3000"
check_service "QDRANT"         "http://llm-01.local:6333/healthz"
check_service "Omada"          "http://llm-01.local:8088"

echo ""
echo "── Network ─────────────────────────────"
for node in llm-01.local llm-02.local llm-03.local; do
    if ping -c 1 -W 1 "$node" &>/dev/null; then
        echo "  ✅ $node reachable"
    else
        echo "  ❌ $node unreachable"
    fi
done
