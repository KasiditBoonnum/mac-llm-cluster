#!/bin/bash
# Pull models for each node based on hostname

HOSTNAME=$(hostname -s)

case $HOSTNAME in
    llm-01)
        echo "Node 1: Pulling Phi-4 14B Q5..."
        ollama pull phi4:14b-q5_K_M
        ;;
    llm-02)
        echo "Node 2: Pulling Qwen2.5 32B Q4..."
        ollama pull qwen2.5:32b-instruct-q4_K_M
        ;;
    llm-03)
        echo "Node 3: Pulling Qwen2.5 32B + DeepSeek 33B..."
        ollama pull qwen2.5:32b-instruct-q4_K_M
        ollama pull deepseek-coder-v2:33b-instruct-q4_K_M
        ;;
    *)
        echo "Unknown node: $HOSTNAME"
        echo "Please pull models manually with: ollama pull <model>"
        exit 1
        ;;
esac

echo ""
echo "✅ Models pulled for $HOSTNAME"
ollama list
