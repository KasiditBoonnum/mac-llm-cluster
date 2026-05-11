#!/bin/bash
# Configure macOS application firewall

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Allow cluster services
for APP in /usr/bin/python3 /opt/homebrew/bin/node_exporter /opt/homebrew/bin/prometheus /opt/homebrew/bin/grafana; do
    if [ -f "$APP" ]; then
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$APP"
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$APP"
    fi
done

echo "✅ Firewall configured"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
