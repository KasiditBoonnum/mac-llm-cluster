#!/bin/bash
# Install AI gateway and queue manager as launchd services.
# Also fixes nginx default server conflict on port 8080.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LAUNCHD_DIR="$REPO_ROOT/config/launchd"
VENV_DIR="$REPO_ROOT/services/ai-gateway/.venv"
PYTHON_BIN="$(which python3.12 || which python3)"

echo "==> Python: $PYTHON_BIN"

# 1. Fix nginx port 8080 conflict (Homebrew nginx default server block)
NGINX_CONF="/opt/homebrew/etc/nginx/nginx.conf"
if [ -f "$NGINX_CONF" ] && grep -q "listen       8080;" "$NGINX_CONF"; then
    echo "==> nginx.conf uses port 8080 - moving default server to 8079 to free port for queue manager"
    sudo sed -i '' 's/listen       8080;/listen       8079;/' "$NGINX_CONF"
    sudo nginx -t && sudo nginx -s reload
    echo "    nginx reloaded"
else
    echo "==> nginx port 8080 not conflicting - OK"
fi

# 2. Create venv and install dependencies
echo "==> Creating virtual environment at $VENV_DIR ..."
"$PYTHON_BIN" -m venv "$VENV_DIR"
PYTHON="$VENV_DIR/bin/python"

echo "==> Installing dependencies..."
"$PYTHON" -m pip install -r "$REPO_ROOT/services/ai-gateway/requirements.txt" --quiet

echo "==> Downloading spaCy model for Presidio..."
"$PYTHON" -m spacy download en_core_web_lg --quiet

# 3. Install LiteLLM proxy
LITELLM="$VENV_DIR/bin/litellm"
LITELLM_PLIST_SRC="$LAUNCHD_DIR/com.llm.litellm-proxy.plist"
LITELLM_PLIST_DEST="$HOME/Library/LaunchAgents/com.llm.litellm-proxy.plist"
echo "==> Installing LiteLLM proxy..."
sed \
    -e "s|YOUR_USERNAME|$(whoami)|g" \
    -e "s|YOUR_LITELLM|$LITELLM|g" \
    "$LITELLM_PLIST_SRC" > "$LITELLM_PLIST_DEST"
launchctl unload "$LITELLM_PLIST_DEST" 2>/dev/null || true
launchctl load -w "$LITELLM_PLIST_DEST"
echo "    LiteLLM proxy started (com.llm.litellm-proxy)"

# 4. Install queue manager
QUEUE_PLIST_SRC="$LAUNCHD_DIR/com.llm.queue-manager.plist"
QUEUE_PLIST_DEST="$HOME/Library/LaunchAgents/com.llm.queue-manager.plist"
echo "==> Installing queue manager..."
sed \
    -e "s|YOUR_USERNAME|$(whoami)|g" \
    -e "s|YOUR_PYTHON|$PYTHON|g" \
    "$QUEUE_PLIST_SRC" > "$QUEUE_PLIST_DEST"
launchctl unload "$QUEUE_PLIST_DEST" 2>/dev/null || true
launchctl load -w "$QUEUE_PLIST_DEST"
echo "    Queue manager started (com.llm.queue-manager)"

# 4. Install AI gateway
GW_PLIST_SRC="$LAUNCHD_DIR/com.llm.ai-gateway.plist"
GW_PLIST_DEST="$HOME/Library/LaunchAgents/com.llm.ai-gateway.plist"
echo "==> Installing AI gateway..."
sed \
    -e "s|YOUR_USERNAME|$(whoami)|g" \
    -e "s|YOUR_PYTHON|$PYTHON|g" \
    "$GW_PLIST_SRC" > "$GW_PLIST_DEST"
launchctl unload "$GW_PLIST_DEST" 2>/dev/null || true
launchctl load -w "$GW_PLIST_DEST"
echo "    AI gateway started (com.llm.ai-gateway)"

# 5. Install SSH tunnels
for NODE in llm02 llm03; do
    TUNNEL_PLIST_SRC="$LAUNCHD_DIR/com.llm.ssh-tunnel-$NODE.plist"
    TUNNEL_PLIST_DEST="$HOME/Library/LaunchAgents/com.llm.ssh-tunnel-$NODE.plist"
    echo "==> Installing SSH tunnel to $NODE..."
    cp "$TUNNEL_PLIST_SRC" "$TUNNEL_PLIST_DEST"
    launchctl unload "$TUNNEL_PLIST_DEST" 2>/dev/null || true
    launchctl load -w "$TUNNEL_PLIST_DEST"
    echo "    SSH tunnel started (com.llm.ssh-tunnel-$NODE)"
done

# 6. Verify
sleep 4
echo ""
echo "==> Verifying..."
QUEUE_OK=$(curl -sf http://localhost:8080/health > /dev/null 2>&1 && echo "healthy" || echo "not responding")
GW_OK=$(curl -sf http://localhost:8082/health > /dev/null 2>&1 && echo "healthy" || echo "not responding")
echo "   Queue manager : $QUEUE_OK"
echo "   AI gateway    : $GW_OK"
echo ""
echo "Done"
echo "   Gateway : http://llm-01.local:8082"
echo "   Queue   : http://llm-01.local:8080"
echo "   Logs    : tail -f /tmp/queue-manager.log /tmp/ai-gateway.log"