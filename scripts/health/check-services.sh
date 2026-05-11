#!/bin/bash
# Check all LaunchAgent services status

echo "=== LaunchAgent Services ==="
echo ""

PLISTS=(
    com.llm.mac-metrics-exporter
    com.llm.inference-metrics-exporter
    com.llm.queue-manager
    com.llm.ollama
    com.llm.discord-bot
    com.llm.log-analyzer
    com.llm.report-generator
)

for PLIST in "${PLISTS[@]}"; do
    STATUS=$(launchctl list "$PLIST" 2>/dev/null | grep '"PID"' | awk '{print $3}' | tr -d ',')
    if [ -n "$STATUS" ] && [ "$STATUS" != "0" ]; then
        echo "  ✅ $PLIST (PID: $STATUS)"
    else
        echo "  ❌ $PLIST (not running)"
    fi
done

echo ""
echo "=== Brew Services ==="
brew services list | grep -E "(node_exporter|prometheus|grafana|nginx)"
