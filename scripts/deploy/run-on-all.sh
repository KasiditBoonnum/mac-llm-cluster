#!/bin/bash
# Run a command on all cluster nodes (including local)
# Usage: ./run-on-all.sh "uname -a"
#        ./run-on-all.sh "brew install jq"
#        ./run-on-all.sh --remote-only "ifconfig en0 | grep mtu"

set -e

REMOTE_ONLY=false
if [ "$1" == "--remote-only" ]; then
    REMOTE_ONLY=true
    shift
fi

COMMAND="$@"

if [ -z "$COMMAND" ]; then
    echo "Usage: $0 [--remote-only] '<command>'"
    exit 1
fi

NODES=("llm-02" "llm-03")
NODE_IPS=("192.168.10.12" "192.168.10.13")

# Run locally first (unless --remote-only)
if [ "$REMOTE_ONLY" = false ]; then
    echo "==================================="
    echo "  Running on llm-01 (local)"
    echo "==================================="
    eval "$COMMAND"
    echo ""
fi

# Run on remote nodes
for i in "${!NODES[@]}"; do
    NODE="${NODES[$i]}"
    NODE_IP="${NODE_IPS[$i]}"

    echo "==================================="
    echo "  Running on $NODE"
    echo "==================================="

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$NODE" "echo connected" &>/dev/null; then
        ssh "$NODE" "$COMMAND" || echo "⚠️  Command failed on $NODE"
    elif ssh -o ConnectTimeout=5 -o BatchMode=yes "$USER@$NODE_IP" "echo connected" &>/dev/null; then
        echo "(using IP fallback)"
        ssh "$USER@$NODE_IP" "$COMMAND" || echo "⚠️  Command failed on $NODE"
    else
        echo "❌ Cannot reach $NODE (mDNS or IP)"
    fi

    echo ""
done

echo "✅ Done"
