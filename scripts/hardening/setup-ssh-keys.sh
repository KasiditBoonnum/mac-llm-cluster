#!/bin/bash
# Setup SSH key authentication on this node

set -e

USERNAME=$(whoami)

# Generate key if not exists
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "$USERNAME@$(hostname -s)"
    echo "✅ SSH key generated"
fi

# Disable password auth after keys are set up
echo ""
echo "⚠️  After verifying key-based login works, run:"
echo "  echo 'PasswordAuthentication no' | sudo tee -a /etc/ssh/sshd_config.d/hardening.conf"
echo "  sudo launchctl kickstart -k system/com.openssh.sshd"
