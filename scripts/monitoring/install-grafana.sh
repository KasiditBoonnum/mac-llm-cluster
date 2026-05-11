#!/bin/bash
# Install Grafana on Node 1

brew install grafana
brew services start grafana

echo "✅ Grafana running on port 3001"
echo "Login: admin / admin (change on first login)"
sleep 3
open http://llm-01.local:3001
