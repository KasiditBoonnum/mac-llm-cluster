#!/bin/bash
# Install Omada Controller via Docker

docker run -d \
  --name omada-controller \
  --restart unless-stopped \
  -p 8088:8088 \
  -p 8043:8043 \
  -e TZ=Asia/Bangkok \
  -v omada-data:/opt/tplink/EAPController/data \
  mbentley/omada-controller:latest

echo "✅ Omada Controller installed"
echo "Access: http://llm-01.local:8088"
echo "Wait ~60 seconds for first boot"
