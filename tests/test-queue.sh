#!/bin/bash
# Test queue system

QUEUE_URL="http://llm-01.local:8080"

echo "=== Queue System Test ==="

# Health check
echo "Health:"
curl -s "$QUEUE_URL/health" | python3 -m json.tool

# Status
echo ""
echo "Status:"
curl -s "$QUEUE_URL/queue/status" | python3 -m json.tool

# Submit a test request
echo ""
echo "Submitting test request..."
RESP=$(curl -s -X POST "$QUEUE_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"phi4:14b-q5_K_M","prompt":"Say hello in one word"}')
echo "$RESP" | python3 -m json.tool

TASK_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['task_id'])" 2>/dev/null)
if [ -n "$TASK_ID" ]; then
    echo ""
    echo "Polling task $TASK_ID..."
    for i in {1..10}; do
        sleep 3
        STATUS=$(curl -s "$QUEUE_URL/tasks/$TASK_ID")
        echo "$STATUS" | python3 -m json.tool
        STATE=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
        [ "$STATE" = "completed" ] || [ "$STATE" = "error" ] && break
    done
fi
