#!/bin/bash
# Install QDRANT via Docker

docker run -d \
  --name qdrant \
  -p 6333:6333 \
  -p 6334:6334 \
  -v qdrant_storage:/qdrant/storage \
  --restart always \
  qdrant/qdrant:latest

echo "✅ QDRANT installed"
sleep 5
echo "Dashboard: http://llm-01.local:6333/dashboard"
curl -s http://localhost:6333/collections | python3 -m json.tool
