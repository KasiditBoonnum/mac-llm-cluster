#!/bin/bash
# Allow powermetrics without password (for temperature monitoring)

USERNAME=$(whoami)
echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/powermetrics" | sudo tee /etc/sudoers.d/powermetrics
sudo chmod 440 /etc/sudoers.d/powermetrics

echo "Sudo configured for powermetrics"
