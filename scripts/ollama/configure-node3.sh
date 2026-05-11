#!/bin/bash
# Configure Node 3 to use port 11435 (allows dynamic model switching)

echo "Configuring Node 3 Ollama on port 11435..."

# Set OLLAMA_HOST in shell profile
echo 'export OLLAMA_HOST=0.0.0.0:11435' >> ~/.zprofile
export OLLAMA_HOST=0.0.0.0:11435

# Create LaunchAgent for Ollama on port 11435
cat > ~/Library/LaunchAgents/com.llm.ollama.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.llm.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0:11435</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.llm.ollama.plist

echo "✅ Node 3 Ollama configured on port 11435"
sleep 3
curl -s http://localhost:11435/api/tags | python3 -m json.tool
