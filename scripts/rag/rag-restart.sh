#!/bin/bash
PLIST="$HOME/Library/LaunchAgents/com.llm.rag-server.plist"

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load -w "$PLIST"
    echo "RAG server restarted (launchd)"
else
    pkill -f qdrant-rag-server.py 2>/dev/null || true
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    nohup python3 "$SCRIPT_DIR/../../services/rag/qdrant-rag-server.py" \
        >> /tmp/rag-server.log 2>> /tmp/rag-server.err &
    echo "RAG server restarted (background)"
fi
