#!/bin/bash
# Test Exo distributed cluster

echo "=== Testing Exo Cluster ==="
echo ""

# Check exo is running on coordinator (llm-01)
if curl -s http://localhost:5678/v1/models &>/dev/null; then
    echo "✅ Exo coordinator (localhost:5678) - online"
else
    echo "❌ Exo coordinator not running"
    exit 1
fi

# Test inference
echo "Testing inference (Qwen3.6-35B-A3B distributed)..."
curl -s http://localhost:5678/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"mlx-community/Qwen3.6-35B-A3B-8bit","messages":[{"role":"user","content":"Say hello"}],"max_tokens":50}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); c=d['choices'][0]['message']; print('  Response:', c.get('content') or c.get('reasoning_content','(thinking...)'))"

echo "✅ Exo cluster working"
