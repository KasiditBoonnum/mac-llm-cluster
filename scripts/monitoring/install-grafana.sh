#!/bin/bash
# Install and provision Grafana on Node 1

set -e

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GRAFANA_PROV="/opt/homebrew/etc/grafana/provisioning"
PLIST="$HOME/Library/LaunchAgents/com.llm.grafana-provision.plist"

brew install grafana

# Configure port 3001
GRAFANA_INI="/opt/homebrew/etc/grafana/grafana.ini"
if ! grep -q "^http_port = 3001" "$GRAFANA_INI" 2>/dev/null; then
    sed -i '' 's/^;http_port = 3000/http_port = 3001/' "$GRAFANA_INI" || \
        echo "http_port = 3001" >> "$GRAFANA_INI"
fi

# Copy provisioning files (datasource only — dashboard via API)
mkdir -p "$GRAFANA_PROV/datasources"
cp "$REPO_DIR/config/grafana/datasources/prometheus.yaml" \
   "$GRAFANA_PROV/datasources/prometheus.yaml"

# Install provision LaunchAgent (runs on every boot to restore dashboard)
mkdir -p ~/Library/LaunchAgents
sed "s/YOUR_USERNAME/$(whoami)/g" \
    "$REPO_DIR/config/launchd/com.llm.grafana-provision.plist" \
    > "$PLIST"

brew services start grafana

# Wait and provision
sleep 5
bash "$REPO_DIR/scripts/monitoring/provision-grafana.sh"

# Load LaunchAgent for future reboots
launchctl unload "$PLIST" 2>/dev/null
launchctl load "$PLIST"

echo "Grafana running on http://llm-01.local:3001"
echo "Dashboard auto-provisions on every reboot"
sleep 3
open http://llm-01.local:3001
