#!/bin/bash
# Master setup script - orchestrates full cluster deployment
# Run from llm-01 only

set -e

echo "Starting full cluster setup from llm-01..."
echo "This will take 1-2 hours depending on model download speed."
echo ""
read -p "Continue? [y/N] " confirm
[ "$confirm" = "y" ] || exit 0

bash scripts/deploy/deploy-all-nodes.sh
