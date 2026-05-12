#!/bin/bash
# Install Exo distributed inference on a node

set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

echo "Installing Python 3.13..."
brew install python@3.13

PYTHON="/opt/homebrew/bin/python3.13"
VENV="$HOME/exo-venv"

# Remove old venv if wrong Python version
if [ -d "$VENV" ]; then
    rm -rf "$VENV"
fi

echo "Creating venv with Python 3.13..."
"$PYTHON" -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip

echo "Installing Exo from GitHub..."
"$VENV/bin/pip" install "exo @ git+https://github.com/exo-explore/exo.git"

echo "Exo installed"
"$VENV/bin/exo" --version 2>/dev/null || echo "Installation complete"
