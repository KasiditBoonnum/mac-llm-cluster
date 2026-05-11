#!/bin/bash
# Deploy everything to all nodes from llm-01
# This is the MASTER script - run this from llm-01 only

set -e

echo "┌──────────────────────────────────────────────┐"
echo "│   LLM Cluster - Remote Deployment           │"
echo "│   Deploy everything from llm-01             │"
echo "└──────────────────────────────────────────────┘"
echo ""

if [ "$(hostname -s)" != "llm-01" ]; then
    echo "❌ This script must run on llm-01"
    exit 1
fi

echo "─────────────────────────────────────────"
echo "  Phase 1: SSH Key Setup"
echo "─────────────────────────────────────────"
bash scripts/deploy/setup-ssh-keys-all.sh

echo ""
echo "─────────────────────────────────────────"
echo "  Phase 2: Bootstrap Remote Nodes"
echo "─────────────────────────────────────────"
bash scripts/deploy/bootstrap-node.sh llm-02
bash scripts/deploy/bootstrap-node.sh llm-03

echo ""
echo "─────────────────────────────────────────"
echo "  Phase 3: Monitoring (Priority Install!)"
echo "─────────────────────────────────────────"
bash scripts/deploy/run-on-all.sh 'cd ~/mac-llm-cluster && bash scripts/monitoring/install-node-exporter.sh'
bash scripts/deploy/run-on-all.sh 'cd ~/mac-llm-cluster && bash scripts/monitoring/install-mac-exporter.sh'
bash scripts/deploy/run-on-all.sh 'cd ~/mac-llm-cluster && bash scripts/monitoring/setup-powermetrics-sudo.sh'
bash scripts/monitoring/install-prometheus.sh
bash scripts/monitoring/install-grafana.sh

echo ""
echo "─────────────────────────────────────────"
echo "  Phase 4: Docker Installation"
echo "─────────────────────────────────────────"
bash scripts/deploy/run-on-all.sh 'cd ~/mac-llm-cluster && bash scripts/docker/install-docker.sh'

echo ""
echo "─────────────────────────────────────────"
echo "  Phase 5: Ollama & Models"
echo "─────────────────────────────────────────"
bash scripts/deploy/run-on-all.sh 'cd ~/mac-llm-cluster && bash scripts/ollama/install-ollama.sh'
bash scripts/deploy/run-on-all.sh 'cd ~/mac-llm-cluster && bash scripts/ollama/pull-models.sh'

echo ""
echo "─────────────────────────────────────────"
echo "  Phase 6: Exo Distributed Mode"
echo "─────────────────────────────────────────"
bash scripts/deploy/run-on-all.sh 'cd ~/mac-llm-cluster && bash scripts/exo/install-exo.sh'

echo ""
echo "─────────────────────────────────────────"
echo "  Phase 7: Node 1 Services"
echo "─────────────────────────────────────────"
bash scripts/nginx/install-nginx.sh
bash scripts/nginx/generate-ssl.sh
bash scripts/qdrant/install-qdrant.sh
bash scripts/webui/install-open-webui-custom.sh
bash scripts/omada/install-omada-controller.sh

echo ""
echo "─────────────────────────────────────────"
echo "  Phase 8: Queue System"
echo "─────────────────────────────────────────"
pip3 install -r services/queue/requirements.txt --break-system-packages
launchctl load ~/Library/LaunchAgents/com.llm.queue-manager.plist

echo ""
echo "┌──────────────────────────────────────────────┐"
echo "│   ✅ DEPLOYMENT COMPLETE!                    │"
echo "└──────────────────────────────────────────────┘"
echo ""
echo "Access Points:"
echo "  Web UI:    https://llm-01.local (or https://192.168.10.11)"
echo "  Grafana:   http://llm-01.local:3001"
echo "  Queue:     http://llm-01.local:8080/queue/status"
echo ""
echo "Next: Configure Web UI users with:"
echo "  bash scripts/nginx/create-users.sh"
