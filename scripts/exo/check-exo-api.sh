#!/bin/bash
# Probe exo API endpoints to discover what's available

BASE="http://localhost:5678"

probe() {
    local path=$1
    local result=$(curl -s -o /dev/null -w "%{http_code}" "$BASE$path")
    echo "  $result  $path"
}

echo "=== Exo API probe on $BASE ==="
probe "/"
probe "/api"
probe "/api/v0"
probe "/api/v0/peers"
probe "/api/v0/nodes"
probe "/api/v0/topology"
probe "/api/v0/models"
probe "/api/v0/download"
probe "/topology"
probe "/peers"
probe "/nodes"
probe "/v1/models"
probe "/v1/download"
probe "/health"
probe "/status"

echo ""
echo "=== Full response from likely endpoints ==="
for path in "/api/v0/peers" "/api/v0/nodes" "/api/v0/topology" "/topology" "/peers"; do
    RESP=$(curl -s "$BASE$path")
    if [ -n "$RESP" ] && [ "$RESP" != "Not Found" ] && ! echo "$RESP" | grep -q '"detail":"Not Found"'; then
        echo "--- $path ---"
        echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
    fi
done
