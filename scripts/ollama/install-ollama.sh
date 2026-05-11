#!/bin/bash
# Install Ollama

curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
ollama serve &
sleep 3

echo "✅ Ollama installed"
ollama --version
