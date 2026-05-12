#!/bin/bash
# Provision Grafana datasource and dashboard via API
# Run once after Grafana starts, or on every boot via LaunchAgent

GRAFANA_URL="http://localhost:3001"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
REPO_DIR="$HOME/mac-llm-cluster"

# Wait for Grafana to be ready
echo "Waiting for Grafana..."
for i in $(seq 1 30); do
    if curl -s "$GRAFANA_URL/api/health" | grep -q "ok"; then
        echo "Grafana is ready"
        break
    fi
    sleep 2
done

# Add Prometheus datasource
echo "Provisioning Prometheus datasource..."
curl -s -X POST "$GRAFANA_URL/api/datasources" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "uid": "prometheus",
        "url": "http://localhost:9090",
        "access": "proxy",
        "isDefault": true,
        "jsonData": { "timeInterval": "15s" }
    }' > /dev/null

# Import dashboard
echo "Importing dashboard..."
DASHBOARD_JSON=$(cat "$REPO_DIR/config/grafana/mac-cluster-dashboard.json")
curl -s -X POST "$GRAFANA_URL/api/dashboards/import" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -H "Content-Type: application/json" \
    -d "{
        \"dashboard\": $DASHBOARD_JSON,
        \"overwrite\": true,
        \"folderId\": 0
    }" > /dev/null

echo "Grafana provisioned — http://llm-01.local:3001"
