#!/bin/bash
# Install and start the RAG server on llm-01

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RAG_DIR="$REPO_ROOT/services/rag"
GW_DIR="$REPO_ROOT/services/ai-gateway"
LAUNCHD_DIR="$REPO_ROOT/config/launchd"
PLIST_NAME="com.llm.rag-server"
PLIST_SRC="$LAUNCHD_DIR/$PLIST_NAME.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
NGINX_CONF_DIR="/opt/homebrew/etc/nginx/servers"
PYTHON="$(which python3)"

echo "==> Python: $PYTHON"

# 1. Qdrant must be running
echo "==> Checking Qdrant..."
if ! curl -sf http://localhost:6333/healthz > /dev/null; then
    echo "❌  Qdrant not running. Start it first:"
    echo "    bash $REPO_ROOT/scripts/qdrant/install-qdrant.sh"
    exit 1
fi
echo "    Qdrant OK (localhost:6333)"

# 2. Install Surya OCR
echo "==> Installing Surya OCR..."
"$PYTHON" -m pip install surya-ocr \
    --break-system-packages --quiet

# 3. Install RAG server Python packages
echo "==> Installing RAG server dependencies..."
"$PYTHON" -m pip install -r "$RAG_DIR/requirements.txt" --break-system-packages --quiet

# 4. Install gateway RAG packages (qdrant-client + sentence-transformers)
echo "==> Installing gateway RAG dependencies..."
"$PYTHON" -m pip install \
    "qdrant-client>=1.7.0" \
    "sentence-transformers>=2.3.0" \
    --break-system-packages --quiet

# 4. Register the RAG server as a launchd service
echo "==> Registering launchd service..."
sed \
    -e "s|YOUR_USERNAME|$(whoami)|g" \
    -e "s|YOUR_PYTHON|$PYTHON|g" \
    "$PLIST_SRC" > "$PLIST_DEST"

launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load -w "$PLIST_DEST"
echo "    RAG server started (com.llm.rag-server)"

# 5. Deploy nginx config for port 8444
echo "==> Deploying nginx config..."
sudo mkdir -p "$NGINX_CONF_DIR"
sudo cp "$REPO_ROOT/config/nginx/conf.d/rag-admin.conf" "$NGINX_CONF_DIR/"
sudo nginx -t && sudo nginx -s reload
echo "    nginx reloaded — port 8444 active"

# 6. Restart AI gateway so it picks up RAG dependencies
echo "==> Restarting AI gateway..."
GW_PLIST="$HOME/Library/LaunchAgents/com.llm.ai-gateway.plist"
if [ -f "$GW_PLIST" ]; then
    launchctl unload "$GW_PLIST" 2>/dev/null || true
    launchctl load -w "$GW_PLIST"
    echo "    Gateway restarted"
else
    echo "    (no gateway plist found — skipping)"
fi

echo ""
echo "✅ RAG stack operational"
echo "   Admin UI : https://llm-01.local:8444/admin"
echo "   API      : http://llm-01.local:8081"
echo "   Qdrant   : http://llm-01.local:6333/dashboard"
echo "   Logs     : tail -f /tmp/rag-server.log /tmp/rag-server.err"
