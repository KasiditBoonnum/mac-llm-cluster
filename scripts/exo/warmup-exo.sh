#!/bin/bash
# Warm up exo cluster — waits for nodes to connect then pre-loads the model

MODEL="mlx-community/Qwen3.6-35B-A3B-8bit"
MAX_WAIT=300
INTERVAL=10

echo "Waiting for exo API..."
until curl -s http://localhost:5678/v1/models &>/dev/null; do
    sleep 3
done
echo "API ready. Waiting 60s for peer discovery..."
sleep 60

echo "Triggering model load (retrying every ${INTERVAL}s, max ${MAX_WAIT}s)..."
elapsed=0
while true; do
    RESPONSE=$(curl -s http://localhost:5678/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}")

    if echo "$RESPONSE" | grep -q '"content"'; then
        echo "✅ Model loaded — cluster ready"
        exit 0
    fi

    MSG=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('message','unknown'))" 2>/dev/null)
    echo "[${elapsed}s] $MSG — retrying..."

    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))

    if [ $elapsed -ge $MAX_WAIT ]; then
        echo ""
        echo "❌ Model did not load after ${MAX_WAIT}s."
        echo "   Open http://localhost:5678 in browser and click Launch on the model, then re-run the stress test."
        exit 1
    fi
done
