#!/bin/bash
# Sync mac-llm-cluster repo to all nodes from llm-01

set -e

NODES=("llm-02" "llm-03")
NODE_IPS=("192.168.10.12" "192.168.10.13")
REPO_DIR="$HOME/mac-llm-cluster"

echo "Syncing repository to all nodes..."
echo ""

for i in "${!NODES[@]}"; do
    NODE="${NODES[$i]}"
    NODE_IP="${NODE_IPS[$i]}"

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$NODE" "echo ok" &>/dev/null; then
        TARGET="$NODE"
    else
        TARGET="$USER@$NODE_IP"
        echo "(using IP for $NODE)"
    fi

    echo "Syncing to $NODE..."
    rsync -avz --exclude='.git' --exclude='node_modules' --exclude='__pycache__' \
        "$REPO_DIR/" "$TARGET:$REPO_DIR/"
    echo "✅ $NODE synced"
    echo ""
done

echo "✅ All nodes synced"
