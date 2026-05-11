#!/bin/bash
# Install Prometheus on Node 1

set -e

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROM_ETC="/opt/homebrew/etc"

brew install prometheus

# Use repo config (includes all 3 nodes + inference + alerts)
cp "$REPO_DIR/config/prometheus/prometheus.yml" "$PROM_ETC/prometheus.yml"
cp "$REPO_DIR/config/prometheus/alerts.yml" "$PROM_ETC/alerts.yml"

brew services start prometheus

echo "Prometheus running on http://llm-01.local:9090"
open http://llm-01.local:9090
