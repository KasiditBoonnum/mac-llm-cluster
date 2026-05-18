#!/bin/bash
# Deploy Nginx configs

REPO_DIR="$HOME/mac-llm-cluster"
NGINX_CONF_DIR="/opt/homebrew/etc/nginx/servers"

sudo cp "$REPO_DIR/config/nginx/conf.d/"*.conf "$NGINX_CONF_DIR/"

sudo nginx -t && sudo brew services restart nginx
echo "✅ Nginx config deployed and restarted"
