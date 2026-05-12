#!/bin/bash
# Install Exo distributed inference on a node

set -e

VENV="$HOME/exo-venv"

echo "Creating Python venv for Exo..."
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install exo-inference

echo "Exo installed at $VENV"
"$VENV/bin/exo" --version
