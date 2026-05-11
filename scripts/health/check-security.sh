#!/bin/bash
# Security audit

echo "=== Security Audit ==="
echo ""

# Firewall
FW=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)
echo "Firewall: $FW"

# SSH config
if grep -q "PermitRootLogin no" /etc/ssh/sshd_config.d/hardening.conf 2>/dev/null; then
    echo "✅ Root SSH login disabled"
else
    echo "⚠️  Root SSH login not disabled"
fi

# Cloud services
if defaults read com.apple.assistant.support "Assistant Enabled" 2>/dev/null | grep -q "0"; then
    echo "✅ Siri disabled"
else
    echo "⚠️  Siri may be enabled"
fi

# Check for open ports
echo ""
echo "Open ports:"
sudo lsof -iTCP -sTCP:LISTEN -n -P | grep -v localhost | awk '{print $9}' | sort -u
