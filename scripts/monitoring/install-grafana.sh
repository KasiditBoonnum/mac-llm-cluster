#!/bin/bash
# Install and provision Grafana on Node 1

set -e

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GRAFANA_PROV="/opt/homebrew/etc/grafana/provisioning"

brew install grafana

# Configure port 3001
GRAFANA_INI="/opt/homebrew/etc/grafana/grafana.ini"
if ! grep -q "^http_port = 3001" "$GRAFANA_INI" 2>/dev/null; then
    sed -i '' 's/^;http_port = 3000/http_port = 3001/' "$GRAFANA_INI" || \
        echo "http_port = 3001" >> "$GRAFANA_INI"
fi

# Provision datasource
mkdir -p "$GRAFANA_PROV/datasources"
cp "$REPO_DIR/config/grafana/datasources/prometheus.yaml" \
   "$GRAFANA_PROV/datasources/prometheus.yaml"

# Provision dashboard provider config
mkdir -p "$GRAFANA_PROV/dashboards"
cp "$REPO_DIR/config/grafana/provisioning/dashboards/dashboards.yaml" \
   "$GRAFANA_PROV/dashboards/dashboards.yaml"

# Copy dashboard JSON files
cp "$REPO_DIR/config/grafana/mac-cluster-dashboard.json" \
   "$GRAFANA_PROV/dashboards/mac-cluster-dashboard.json"
cp "$REPO_DIR/config/grafana/inference-dashboard.json" \
   "$GRAFANA_PROV/dashboards/inference-dashboard.json"

brew services restart grafana

echo "Grafana running on http://llm-01.local:3001"
echo "Login: admin / admin (change on first login)"
echo "Dashboard: Mac LLM Cluster auto-provisioned"
sleep 3
open http://llm-01.local:3001
