#!/bin/bash
# Install Exo distributed inference on a node

set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

# Exo requires Python 3.12+
echo "Installing Python 3.12..."
brew install python@3.12

PYTHON="/opt/homebrew/bin/python3.12"
VENV="$HOME/exo-venv"

echo "Creating venv with Python 3.12..."
"$PYTHON" -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip

echo "Installing Exo from GitHub..."
"$VENV/bin/pip" install "exo @ git+https://github.com/exo-explore/exo.git"

echo "Exo installed"
"$VENV/bin/exo" --version 2>/dev/null || echo "Run 'exo --version' to verify"
