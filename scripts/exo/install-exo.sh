#!/bin/bash
# Install Exo distributed inference on a node

set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

echo "Installing Python 3.13 and Rust..."
brew install python@3.13 rust

PYTHON="/opt/homebrew/bin/python3.13"
VENV="$HOME/exo-venv"
SRC="$HOME/exo-source"

rm -rf "$VENV" "$SRC"

echo "Creating venv with Python 3.13..."
"$PYTHON" -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip maturin

echo "Cloning Exo source..."
git clone --depth=1 https://github.com/exo-explore/exo.git "$SRC"

echo "Building Rust extension (takes 5-15 min)..."
cd "$SRC/rust/exo_pyo3_bindings"
"$VENV/bin/maturin" build --release
WHEEL=$(ls "$SRC/rust/exo_pyo3_bindings/target/wheels/"*.whl 2>/dev/null | head -1)
if [ -n "$WHEEL" ]; then
    "$VENV/bin/pip" install "$WHEEL"
fi

echo "Installing Exo..."
cd "$SRC"
"$VENV/bin/pip" install -e .

echo "Exo installed"
"$VENV/bin/exo" --version 2>/dev/null || echo "Installation complete"
