#!/bin/bash
# Install Mac metrics exporter (CPU, GPU, RAM, Temperature)

REPO_DIR="$HOME/mac-llm-cluster"

pip3 install prometheus_client psutil --break-system-packages

# Install LaunchAgent
sed "s/YOUR_USERNAME/$(whoami)/g" \
    "$REPO_DIR/config/launchd/com.llm.mac-metrics-exporter.plist" \
    > ~/Library/LaunchAgents/com.llm.mac-metrics-exporter.plist

launchctl load ~/Library/LaunchAgents/com.llm.mac-metrics-exporter.plist

echo "✅ Mac Metrics Exporter installed on port 9101"
sleep 3
curl -s http://localhost:9101/metrics | grep "^mac_" | head -10
