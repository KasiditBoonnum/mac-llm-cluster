#!/bin/bash
# Generate self-signed SSL certificate

SSL_DIR="/opt/homebrew/etc/nginx/ssl"
sudo mkdir -p "$SSL_DIR"

sudo openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
  -keyout "$SSL_DIR/nginx.key" \
  -out "$SSL_DIR/nginx.crt" \
  -subj "/C=TH/ST=Bangkok/L=Bangkok/O=LLM Cluster/CN=llm-01.local"

sudo chmod 600 "$SSL_DIR/nginx.key"
echo "✅ SSL certificate generated (valid 10 years)"
echo "Location: $SSL_DIR"
