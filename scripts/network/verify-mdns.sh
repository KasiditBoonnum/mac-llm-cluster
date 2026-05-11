#!/bin/bash
# Verify mDNS (.local hostnames) are working

NODES=("llm-01.local" "llm-02.local" "llm-03.local")
IPS=("192.168.10.11" "192.168.10.12" "192.168.10.13")

echo "=== mDNS Verification ==="
echo ""

for i in "${!NODES[@]}"; do
    NODE="${NODES[$i]}"
    IP="${IPS[$i]}"

    if ping -c 1 -W 1 "$NODE" &>/dev/null; then
        echo "✅ $NODE - reachable via mDNS"
    elif ping -c 1 -W 1 "$IP" &>/dev/null; then
        echo "⚠️  $NODE - mDNS failed, IP $IP works (add to /etc/hosts)"
    else
        echo "❌ $NODE ($IP) - unreachable"
    fi
done
