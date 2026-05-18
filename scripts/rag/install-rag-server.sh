#!/bin/bash
# Install and register the RAG server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RAG_DIR="$REPO_ROOT/services/rag"
LAUNCHD_DIR="$REPO_ROOT/config/launchd"
PLIST_NAME="com.llm.rag-server"
PLIST_SRC="$LAUNCHD_DIR/$PLIST_NAME.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

echo "==> Installing RAG server dependencies..."
pip3 install -r "$RAG_DIR/requirements.txt"

echo "==> Registering launchd service..."
sed "s|YOUR_USERNAME|$(whoami)|g" "$PLIST_SRC" > "$PLIST_DEST"

launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load -w "$PLIST_DEST"

echo "==> Reloading nginx..."
nginx -t && nginx -s reload

echo ""
echo "Done. RAG admin UI: https://llm-01.local:8444/admin"
echo "Logs: tail -f /tmp/rag-server.log /tmp/rag-server.err"
