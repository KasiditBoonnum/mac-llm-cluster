#!/bin/bash
# Start Exo node — runs on all 3 nodes, they auto-discover each other

VENV="$HOME/exo-venv"

"$VENV/bin/exo" \
    --inference-engine mlx \
    --chatgpt-api-port 5678 \
    --default-model "mlx-community/Qwen3-30B-A3B-4bit" \
    --max-generate-tokens 8192
