#!/bin/bash
# Warm up exo cluster — triggers model launch via API then waits until ready

MODEL="mlx-community/Qwen3.6-35B-A3B-8bit"
MAX_WAIT=120
INTERVAL=3

echo "Waiting for exo API..."
until curl -s http://localhost:5678/v1/models &>/dev/null; do
    sleep 2
done
echo "API ready. Waiting 15s for all 3 nodes to connect..."
sleep 15

echo "Triggering model launch across all 3 nodes..."
PLACEMENT=$(curl -s -X POST http://localhost:5678/place_instance \
    -H "Content-Type: application/json" \
    -d "{\"model_id\":\"$MODEL\",\"sharding\":\"Pipeline\",\"instance_meta\":\"MlxRing\",\"min_nodes\":3}")

echo "Placement: $PLACEMENT"

INSTANCE=$(echo "$PLACEMENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('instance', d)))" 2>/dev/null)

if [ -n "$INSTANCE" ] && [ "$INSTANCE" != "null" ]; then
    LAUNCH=$(curl -s -X POST http://localhost:5678/instance \
        -H "Content-Type: application/json" \
        -d "{\"instance\": $INSTANCE}")
    echo "Launch: $LAUNCH"
fi

echo "Waiting for model to respond..."
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

    echo "[${elapsed}s] not ready yet..."

    if [ $elapsed -ge $MAX_WAIT ]; then
        echo "❌ Timed out after ${MAX_WAIT}s — open http://localhost:5678 and click Launch manually"
        exit 1
    fi
done
