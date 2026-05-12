#!/bin/bash
# Install Mac metrics exporter (CPU, GPU, RAM, Temperature)

REPO_DIR="$HOME/mac-llm-cluster"
PLIST="$HOME/Library/LaunchAgents/com.llm.mac-metrics-exporter.plist"

pip3 install --user prometheus_client psutil

mkdir -p ~/Library/LaunchAgents

sed "s/YOUR_USERNAME/$(whoami)/g" \
    "$REPO_DIR/config/launchd/com.llm.mac-metrics-exporter.plist" \
    > "$PLIST"

# Unload first if already running
launchctl unload "$PLIST" 2>/dev/null
launchctl load "$PLIST"

echo "Mac Metrics Exporter installed on port 9101"
sleep 3
curl -s http://localhost:9101/metrics | grep "^mac_" | head -10
