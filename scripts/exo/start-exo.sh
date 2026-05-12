#!/bin/bash
# Start Exo node — runs on all 3 nodes, they auto-discover each other

VENV="$HOME/exo-venv"

"$VENV/bin/exo" --api-port 5678
