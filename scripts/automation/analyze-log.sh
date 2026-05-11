#!/bin/bash
# On-demand log analysis using local LLM
# Usage: ./analyze-log.sh /var/log/nginx/error.log

LOG_FILE="${1:-/var/log/system.log}"
OLLAMA_URL="http://llm-01.local:11434"
MODEL="phi4:14b-q5_K_M"

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: $LOG_FILE not found"
    exit 1
fi

echo "Analyzing $LOG_FILE with $MODEL..."
LOG_CONTENT=$(tail -100 "$LOG_FILE")

RESPONSE=$(curl -s "$OLLAMA_URL/api/generate" \
    -d "{
        \"model\": \"$MODEL\",
        \"prompt\": \"Analyze these logs and summarize: errors, warnings, and anomalies. Be concise.\n\nLogs:\n$LOG_CONTENT\",
        \"stream\": false
    }" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])")

echo "=== Analysis ==="
echo "$RESPONSE"

# Save to logs directory
DATE=$(date +%Y%m%d_%H%M%S)
echo "$RESPONSE" > "$HOME/mac-llm-cluster/logs/analysis/analysis-$DATE.txt"
echo ""
echo "✅ Analysis saved to logs/analysis/analysis-$DATE.txt"
