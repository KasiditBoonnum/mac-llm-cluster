#!/bin/bash
# Install Docker Desktop

brew install --cask docker

echo "✅ Docker installed"
echo "IMPORTANT: Open Docker.app to complete setup and accept the license"
open /Applications/Docker.app
echo ""
echo "After Docker starts, configure resources:"
echo "  Docker Desktop → Settings → Resources"
echo "  Recommended: 8+ CPUs, 16GB RAM on Node 1"
echo "               4 CPUs, 8GB RAM on Node 2/3"
