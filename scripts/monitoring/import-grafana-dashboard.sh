#!/bin/bash
# Import Grafana dashboards via API

GRAFANA_URL="http://localhost:3001"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"
REPO_DIR="$HOME/mac-llm-cluster"

# Add Prometheus datasource
curl -s -X POST "$GRAFANA_URL/api/datasources" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://localhost:9090",
        "access": "proxy",
        "isDefault": true
    }'

echo ""
echo "✅ Prometheus datasource added"

# Import dashboards
for DASHBOARD in "$REPO_DIR/config/grafana/"*.json; do
    echo "Importing $(basename "$DASHBOARD")..."
    PAYLOAD=$(jq -n --argjson dashboard "$(cat "$DASHBOARD")" \
        '{"dashboard": $dashboard, "overwrite": true, "folderId": 0}')
    curl -s -X POST "$GRAFANA_URL/api/dashboards/import" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD"
    echo ""
done

echo "✅ Dashboards imported"
echo "Open: $GRAFANA_URL"
