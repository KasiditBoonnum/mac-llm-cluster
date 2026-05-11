#!/bin/bash
# Bootstrap a fresh node from llm-01
# Usage: ./bootstrap-node.sh llm-02

set -e

NODE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$NODE" ]; then
    echo "Usage: $0 <node-name>"
    echo "Example: $0 llm-02"
    exit 1
fi

NODE_ADDR=$(bash "$SCRIPT_DIR/resolve-node.sh" "$NODE")
echo "Bootstrapping $NODE ($NODE_ADDR)..."
echo ""

echo "[1/6] Installing Homebrew..."
ssh "$NODE_ADDR" 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

echo "[2/6] Configuring shell..."
ssh "$NODE_ADDR" 'echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile'

echo "[3/6] Updating /etc/hosts..."
ssh "$NODE_ADDR" 'cat << HOSTS | sudo tee -a /etc/hosts
192.168.10.11   llm-01 llm-01.local
192.168.10.12   llm-02 llm-02.local
192.168.10.13   llm-03 llm-03.local
HOSTS'

echo "[4/6] Applying security hardening..."
ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/hardening/enterprise-hardening.sh'

echo "[5/6] Enabling jumbo frames..."
ssh "$NODE_ADDR" 'cd ~/mac-llm-cluster && bash scripts/network/enable-jumbo-frames.sh'

echo "[6/6] Syncing repository..."
rsync -avz --exclude='.git' ~/mac-llm-cluster/ "$NODE_ADDR:~/mac-llm-cluster/"

echo ""
echo "=========================================="
echo "  ✅ $NODE Bootstrap Complete"
echo "=========================================="
echo ""
echo "Next: bash scripts/deploy/deploy-to-node.sh $NODE"
