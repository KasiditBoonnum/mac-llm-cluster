#!/usr/bin/env bash
set -euo pipefail

# Deploy webui via docker compose (from repo root)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/services/webui/docker-compose.yml"

echo "Using compose file: $COMPOSE_FILE"
docker compose -f "$COMPOSE_FILE" up -d --build

echo "webui deployed"
