#!/bin/bash
# Warm up exo cluster — opens dashboard for model launch, then waits until ready
# NOTE: /place_instance and /instance APIs lock GPU memory and cannot be safely
# called from shell — use the dashboard Launch button instead.

MODEL="mlx-community/Qwen3.6-35B-A3B-8bit"
MAX_WAIT=120
INTERVAL=3

echo "Waiting for exo API..."
until curl -s http://localhost:5678/v1/models &>/dev/null; do
    sleep 2
done
echo "API ready."

echo "Checking if model is already loaded..."
RESPONSE=$(curl -s http://localhost:5678/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}")

if echo "$RESPONSE" | grep -q '"content"'; then
    echo "✅ Model already loaded — cluster ready"
    exit 0
fi

echo ""
echo "⚠️  Model not loaded. Opening dashboard — click Launch on the model."
open http://localhost:5678
echo "Waiting up to ${MAX_WAIT}s for model to respond..."

elapsed=0
while true; do
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))

    RESPONSE=$(curl -s http://localhost:5678/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}")

    if echo "$RESPONSE" | grep -q '"content"'; then
        echo "✅ Cluster ready in ${elapsed}s"
        exit 0
    fi

    echo "[${elapsed}s] waiting..."

    if [ $elapsed -ge $MAX_WAIT ]; then
        echo "❌ Timed out — click Launch in the browser at http://localhost:5678"
        exit 1
    fi
done
