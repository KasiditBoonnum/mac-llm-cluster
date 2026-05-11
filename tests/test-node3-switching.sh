#!/bin/bash
# Test Node 3 dynamic model switching

NODE3_URL="http://llm-03.local:11435"

echo "=== Node 3 Switching Test ==="

echo "Current models on Node 3:"
curl -s "$NODE3_URL/api/tags" | python3 -c "import sys,json; [print(' -', m['name']) for m in json.load(sys.stdin).get('models',[])]"

echo ""
echo "Switching to DeepSeek..."
python3 services/queue/node3-switcher.py deepseek

echo ""
echo "Models after switch:"
curl -s "$NODE3_URL/api/tags" | python3 -c "import sys,json; [print(' -', m['name']) for m in json.load(sys.stdin).get('models',[])]"

echo ""
echo "Switching back to Qwen..."
python3 services/queue/node3-switcher.py qwen

echo "✅ Switching test complete"
