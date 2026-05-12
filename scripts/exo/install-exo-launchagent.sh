#!/bin/bash
# Install Exo LaunchAgent for auto-start on login

REPO_DIR="$HOME/mac-llm-cluster"
PLIST="$HOME/Library/LaunchAgents/com.llm.exo.plist"

mkdir -p ~/Library/LaunchAgents

sed "s/YOUR_USERNAME/$(whoami)/g" \
    "$REPO_DIR/config/launchd/com.llm.exo.plist" \
    > "$PLIST"

launchctl unload "$PLIST" 2>/dev/null
launchctl load "$PLIST"

echo "Exo LaunchAgent installed — auto-starts on login"
echo "Logs: /tmp/exo.log and /tmp/exo.err"
