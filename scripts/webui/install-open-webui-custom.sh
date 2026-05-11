#!/bin/bash
# Install Open WebUI with custom config

docker run -d \
  --name open-webui \
  -p 3000:8080 \
  -v open-webui:/app/backend/data \
  --restart always \
  -e OLLAMA_BASE_URLS="http://llm-01.local:11434;http://llm-02.local:11434;http://llm-03.local:11435" \
  -e WEBUI_AUTH=true \
  -e ENABLE_SIGNUP=false \
  -e WEBUI_NAME="Enterprise LLM Cluster" \
  ghcr.io/open-webui/open-webui:main

echo "✅ Open WebUI installed"
echo "Access: https://llm-01.local (via Nginx)"
echo "Direct: http://llm-01.local:3000"
