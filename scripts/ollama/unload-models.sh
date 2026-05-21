#!/bin/bash
# Evict all Ollama models from RAM on all 3 nodes.
# Ollama stays running — models reload on next request.

echo "==> llm-01: unloading phi4"
curl -s http://llm-01.local:11434/api/generate -d '{"model":"phi4:latest","keep_alive":0}' > /dev/null

echo "==> llm-02: unloading qwen2.5"
ssh llm-02 "curl -s http://localhost:11434/api/generate -d '{\"model\":\"qwen2.5:32b-instruct-q4_K_M\",\"keep_alive\":0}'" > /dev/null

echo "==> llm-03: unloading qwen2.5"
ssh llm-03 "curl -s http://localhost:11434/api/generate -d '{\"model\":\"qwen2.5:32b-instruct-q4_K_M\",\"keep_alive\":0}'" > /dev/null
echo "==> llm-03: unloading deepseek-coder"
ssh llm-03 "curl -s http://localhost:11434/api/generate -d '{\"model\":\"deepseek-coder:33b-instruct-q4_K_M\",\"keep_alive\":0}'" > /dev/null

echo "Done — all models unloaded"
