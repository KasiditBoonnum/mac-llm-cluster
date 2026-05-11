#!/bin/bash
# Install Nginx on Node 1

brew install nginx

sudo mkdir -p /opt/homebrew/etc/nginx/{conf.d,ssl,auth}

echo "✅ Nginx installed"
echo "Next steps:"
echo "  1. bash scripts/nginx/generate-ssl.sh"
echo "  2. bash scripts/nginx/create-users.sh"
echo "  3. bash scripts/nginx/install-config.sh"
