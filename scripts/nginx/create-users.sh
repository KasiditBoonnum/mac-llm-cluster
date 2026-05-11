#!/bin/bash
# Create htpasswd users for Nginx auth

AUTH_FILE="/opt/homebrew/etc/nginx/auth/webui.htpasswd"
sudo mkdir -p "$(dirname "$AUTH_FILE")"

# Install htpasswd if not present
which htpasswd &>/dev/null || brew install httpd

read -p "Username: " USERNAME
read -sp "Password: " PASSWORD
echo

echo "$PASSWORD" | sudo htpasswd -i -c "$AUTH_FILE" "$USERNAME"
echo "✅ User '$USERNAME' created"
echo ""
echo "Add more users with:"
echo "  echo '<password>' | sudo htpasswd -i $AUTH_FILE <username>"
