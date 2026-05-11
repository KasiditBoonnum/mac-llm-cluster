#!/bin/bash
# Helper: Resolve node name to working address (mDNS or IP fallback)
# Usage: ADDR=$(./resolve-node.sh llm-02)

NODE=$1

declare -A NODE_IPS=(
    ["llm-01"]="192.168.10.11"
    ["llm-02"]="192.168.10.12"
    ["llm-03"]="192.168.10.13"
)

# Try mDNS first
if ping -c 1 -W 1 "$NODE.local" &>/dev/null; then
    echo "$NODE.local"
    exit 0
fi

# Fallback to IP
IP="${NODE_IPS[$NODE]}"
if [ -n "$IP" ] && ping -c 1 -W 1 "$IP" &>/dev/null; then
    echo "$IP"
    exit 0
fi

echo "ERROR: Cannot reach $NODE" >&2
exit 1
