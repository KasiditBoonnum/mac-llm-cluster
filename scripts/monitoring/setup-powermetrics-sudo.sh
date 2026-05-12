#!/bin/bash
# Allow powermetrics without password prompt (for GPU/power metrics)
# Must be run as the normal user (not sudo bash) — uses logname to get real username

USERNAME=$(logname 2>/dev/null || whoami)
echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/powermetrics" | sudo tee /etc/sudoers.d/powermetrics
sudo chmod 440 /etc/sudoers.d/powermetrics
echo "Configured sudoers for: $USERNAME"
