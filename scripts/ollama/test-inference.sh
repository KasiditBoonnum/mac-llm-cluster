#!/bin/bash
# Test inference on all nodes

echo "=== Testing Inference on All Nodes ==="
echo ""

# Node 1 - Phi-4
echo "Node 1 (phi4:14b-q5_K_M)..."
curl -s http://llm-01.local:11434/api/generate \
    -d '{"model":"phi4:14b-q5_K_M","prompt":"Say hello in one word","stream":false}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Response: {d[\"response\"]}')" 2>/dev/null || echo "  ❌ Node 1 failed"

# Node 2 - Qwen
echo "Node 2 (qwen2.5:32b-instruct-q4_K_M)..."
curl -s http://llm-02.local:11434/api/generate \
    -d '{"model":"qwen2.5:32b-instruct-q4_K_M","prompt":"Say hello in one word","stream":false}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Response: {d[\"response\"]}')" 2>/dev/null || echo "  ❌ Node 2 failed"

# Node 3 - Qwen (port 11435)
echo "Node 3 (qwen2.5:32b-instruct-q4_K_M on :11435)..."
curl -s http://llm-03.local:11435/api/generate \
    -d '{"model":"qwen2.5:32b-instruct-q4_K_M","prompt":"Say hello in one word","stream":false}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Response: {d[\"response\"]}')" 2>/dev/null || echo "  ❌ Node 3 failed"

echo ""
echo "✅ Inference test complete"
