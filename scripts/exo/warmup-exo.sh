#!/bin/bash
# Warm up exo cluster — waits for all nodes to connect then pre-loads the model
# Run this on llm-01 after starting exo on all 3 nodes

MODEL="mlx-community/Qwen3.6-35B-A3B-8bit"
MAX_WAIT=300  # 5 minutes max
INTERVAL=10

echo "Waiting for exo API to be ready..."
elapsed=0
until curl -s http://localhost:5678/v1/models &>/dev/null; do
    sleep 3
    elapsed=$((elapsed + 3))
    if [ $elapsed -ge $MAX_WAIT ]; then
        echo "ERROR: exo API never came up"
        exit 1
    fi
done
echo "API ready. Triggering model load (retrying until all nodes connected)..."

elapsed=0
while true; do
    RESPONSE=$(curl -s http://localhost:5678/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}")

    if echo "$RESPONSE" | grep -q '"content"'; then
        echo "Model loaded and responding — cluster ready"
        exit 0
    elif echo "$RESPONSE" | grep -q '"error"'; then
        MSG=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['error']['message'])" 2>/dev/null)
        echo "[$elapsed s] Not ready: $MSG — retrying in ${INTERVAL}s..."
    fi

    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
    if [ $elapsed -ge $MAX_WAIT ]; then
        echo "ERROR: model never loaded after ${MAX_WAIT}s"
        exit 1
    fi
done
