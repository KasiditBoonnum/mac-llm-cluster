#!/bin/bash
# Deploy a specific service to a specific node
# Usage: ./deploy-to-node.sh llm-02 monitoring

set -e

NODE=$1
SERVICE=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$NODE" ] || [ -z "$SERVICE" ]; then
    echo "Usage: $0 <node> <service>"
    echo "Services: monitoring, docker, ollama, exo, rag, all"
    exit 1
fi

NODE_ADDR=$(bash "$SCRIPT_DIR/resolve-node.sh" "$NODE")
echo "Deploying $SERVICE to $NODE ($NODE_ADDR)..."

case $SERVICE in
    monitoring)
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/monitoring/install-node-exporter.sh'
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/monitoring/install-mac-exporter.sh'
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/monitoring/setup-powermetrics-sudo.sh'
        ;;
    docker)
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/docker/install-docker.sh'
        ;;
    ollama)
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/ollama/install-ollama.sh'
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/ollama/pull-models.sh'
        ;;
    exo)
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/exo/install-exo.sh'
        ;;
    rag)
        ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/rag/install-rag-server.sh'
        ;;
    all)
        bash "$0" "$NODE" monitoring
        bash "$0" "$NODE" docker
        bash "$0" "$NODE" ollama
        bash "$0" "$NODE" exo
        ;;
    *)
        echo "Unknown service: $SERVICE"
        exit 1
        ;;
esac

echo "✅ $SERVICE deployed to $NODE"
