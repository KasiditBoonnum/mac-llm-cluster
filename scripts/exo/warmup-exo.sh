#!/bin/bash
# Warm up exo cluster — triggers model launch via API then waits until ready

MODEL="mlx-community/Qwen3.6-35B-A3B-8bit"
MAX_WAIT=300
INTERVAL=10

echo "Waiting for exo API..."
until curl -s http://localhost:5678/v1/models &>/dev/null; do
    sleep 3
done
echo "API ready. Waiting 30s for peers to connect..."
sleep 30

echo "Placing instance for $MODEL..."
PLACEMENT=$(curl -s -X POST http://localhost:5678/place_instance \
    -H "Content-Type: application/json" \
    -d "{\"model_id\":\"$MODEL\",\"sharding\":\"Pipeline\",\"instance_meta\":\"MlxRing\",\"min_nodes\":1}")

echo "Placement response: $PLACEMENT"

INSTANCE=$(echo "$PLACEMENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('instance', d)))" 2>/dev/null)

if [ -n "$INSTANCE" ] && [ "$INSTANCE" != "null" ]; then
    echo "Launching instance..."
    LAUNCH=$(curl -s -X POST http://localhost:5678/instance \
        -H "Content-Type: application/json" \
        -d "{\"instance\": $INSTANCE}")
    echo "Launch response: $LAUNCH"
else
    echo "No instance in placement response — model may already be loaded or nodes not ready"
fi

echo "Waiting for model to respond (up to ${MAX_WAIT}s)..."
elapsed=0
while true; do
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))

    RESPONSE=$(curl -s http://localhost:5678/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}")

    if echo "$RESPONSE" | grep -q '"content"'; then
        echo "✅ Model loaded — cluster ready"
        exit 0
    fi

    MSG=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('message','unknown'))" 2>/dev/null)
    echo "[${elapsed}s] $MSG"

    if [ $elapsed -ge $MAX_WAIT ]; then
        echo "❌ Timed out. Open http://localhost:5678 and click Launch manually."
        exit 1
    fi
done
