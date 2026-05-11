#!/bin/bash
# Update all services across the cluster

set -e

echo "=== Updating LLM Cluster ==="
echo ""

# Update repo on all nodes
bash scripts/deploy/sync-configs.sh

# Update Homebrew packages on all nodes
bash scripts/deploy/run-on-all.sh "brew update && brew upgrade node_exporter prometheus grafana nginx 2>/dev/null; echo done"

# Update Docker images on Node 1
docker pull ghcr.io/open-webui/open-webui:main
docker pull qdrant/qdrant:latest
docker pull mbentley/omada-controller:latest

# Restart Docker containers
docker restart open-webui qdrant

# Restart queue manager
launchctl unload ~/Library/LaunchAgents/com.llm.queue-manager.plist 2>/dev/null
pip3 install -r services/queue/requirements.txt --break-system-packages --quiet
launchctl load ~/Library/LaunchAgents/com.llm.queue-manager.plist

echo "✅ Update complete"
bash scripts/health/check-cluster.sh
