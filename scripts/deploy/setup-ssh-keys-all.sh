#!/bin/bash
# Setup SSH keys from llm-01 to llm-02 and llm-03
# Run this ONCE from llm-01 only

set -e

NODES=("llm-02" "llm-03")
NODE_IPS=("192.168.10.12" "192.168.10.13")
USERNAME=$(whoami)

echo "=========================================="
echo "  SSH Key Setup - Remote Control"
echo "=========================================="
echo ""

# Generate SSH key if not exists
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "llm-01-cluster-admin"
    echo "✅ SSH key generated"
fi

# Setup SSH config for easy access (with IP fallback)
cat > ~/.ssh/config << EOF
# LLM Cluster SSH Configuration
# Tries hostname first, falls back to IP

Host llm-02
    HostName llm-02.local
    User $USERNAME
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ConnectTimeout 5

Host llm-02-ip
    HostName 192.168.10.12
    User $USERNAME
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new

Host llm-03
    HostName llm-03.local
    User $USERNAME
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ConnectTimeout 5

Host llm-03-ip
    HostName 192.168.10.13
    User $USERNAME
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
EOF

chmod 600 ~/.ssh/config
echo "✅ SSH config created"
echo ""

# Copy SSH key to each node (try hostname first, then IP)
for i in "${!NODES[@]}"; do
    NODE="${NODES[$i]}"
    NODE_IP="${NODE_IPS[$i]}"

    echo "Setting up $NODE ($NODE_IP)..."

    if ssh-copy-id -i ~/.ssh/id_ed25519.pub -o ConnectTimeout=5 "$NODE.local" 2>/dev/null; then
        echo "✅ Connected via $NODE.local"
    else
        echo "⚠️  mDNS failed, using IP $NODE_IP..."
        ssh-copy-id -i ~/.ssh/id_ed25519.pub "$USERNAME@$NODE_IP"
        echo "✅ Connected via IP $NODE_IP"
    fi
done

echo ""
echo "=========================================="
echo "  ✅ SSH Setup Complete!"
echo "=========================================="
echo ""
echo "Test remote access:"
echo "  ssh llm-02       # via mDNS"
echo "  ssh llm-02-ip    # via IP (fallback)"
echo "  ssh llm-03"
echo "  ssh llm-03-ip"
