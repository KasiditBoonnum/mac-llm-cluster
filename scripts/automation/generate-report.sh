#!/bin/bash
# Generate cluster status report using local LLM

OLLAMA_URL="http://llm-01.local:11434"
MODEL="phi4:14b-q5_K_M"
DATE=$(date +%Y%m%d_%H%M%S)

# Gather metrics
QUEUE_STATUS=$(curl -s http://llm-01.local:8080/queue/status 2>/dev/null || echo '{"error":"queue offline"}')
DISK_USAGE=$(df -h / | tail -1)
UPTIME=$(uptime)

CONTEXT="Date: $(date)
Uptime: $UPTIME
Disk: $DISK_USAGE
Queue: $QUEUE_STATUS"

REPORT=$(curl -s "$OLLAMA_URL/api/generate" \
    -d "{
        \"model\": \"$MODEL\",
        \"prompt\": \"Generate a brief cluster status report from this data. Format: Summary, Issues, Recommendations.\n\n$CONTEXT\",
        \"stream\": false
    }" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])")

echo "=== Cluster Report - $(date) ==="
echo "$REPORT"

echo "$REPORT" > "$HOME/mac-llm-cluster/logs/reports/report-$DATE.txt"
echo ""
echo "✅ Report saved to logs/reports/report-$DATE.txt"
