#!/bin/bash
# Install Exo for distributed inference

pip3 install exo --break-system-packages

echo "✅ Exo installed"
exo --version || echo "Run 'exo --version' after shell restart"
