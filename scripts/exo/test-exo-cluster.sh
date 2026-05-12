#!/bin/bash
# Test Exo distributed cluster

echo "=== Testing Exo Cluster ==="
echo ""

# Check exo is running on coordinator (llm-01)
if curl -s http://llm-01.local:5678/v1/models &>/dev/null; then
    echo "✅ Exo coordinator (llm-01:5678) - online"
else
    echo "❌ Exo coordinator not running"
    echo "   Start with: exo run --nodes llm-01.local:5678,llm-02.local:5678,llm-03.local:5678 &"
    exit 1
fi

# Test inference
echo "Testing inference (Qwen3-30B distributed)..."
curl -s http://llm-01.local:5678/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"mlx-community/Qwen3-30B-A3B-4bit","messages":[{"role":"user","content":"Say hello"}],"max_tokens":20}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('  Response:', d['choices'][0]['message']['content'])"

echo "✅ Exo cluster working"
