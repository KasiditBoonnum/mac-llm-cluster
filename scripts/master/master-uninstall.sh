#!/bin/bash
# Uninstall all cluster services

echo "⚠️  This will stop and remove all LLM cluster services."
read -p "Continue? [y/N] " confirm
[ "$confirm" = "y" ] || exit 0

# Stop LaunchAgents
for PLIST in ~/Library/LaunchAgents/com.llm.*.plist; do
    launchctl unload "$PLIST" 2>/dev/null && echo "Stopped: $PLIST"
done

# Stop Brew services
brew services stop node_exporter prometheus grafana nginx 2>/dev/null

# Stop Docker containers
docker stop open-webui qdrant omada-controller 2>/dev/null
docker rm open-webui qdrant omada-controller 2>/dev/null

echo "✅ Services stopped"
echo "Note: Models (ollama pull) and data volumes are preserved"
echo "Run 'docker volume rm open-webui qdrant_storage' to remove data"
