#!/bin/bash
# Enterprise security hardening

echo "=== Enterprise Security Hardening ==="

# 1. Never sleep
sudo pmset -a sleep 0
sudo pmset -a displaysleep 0
sudo pmset -a disksleep 0
sudo pmset -a autopoweroff 0
sudo pmset -a autorestart 1

# 2. Disable cloud services
defaults write com.apple.icloud-container-services Enabled -bool false
defaults write com.apple.assistant.support "Assistant Enabled" -bool false

# 3. Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on

# 4. SSH hardening
echo "PermitRootLogin no" | sudo tee /etc/ssh/sshd_config.d/hardening.conf
echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config.d/hardening.conf
echo "MaxAuthTries 3" | sudo tee -a /etc/ssh/sshd_config.d/hardening.conf

echo "✅ Security hardening complete"
echo "Next: Setup SSH keys, then add 'PasswordAuthentication no' to SSH config"
