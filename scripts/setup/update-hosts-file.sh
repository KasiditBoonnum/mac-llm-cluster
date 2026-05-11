#!/bin/bash
# Update /etc/hosts on llm-01 (and optionally other nodes)

cat << 'EOF' | sudo tee -a /etc/hosts

# LLM Cluster Nodes (IP fallback for mDNS)
192.168.10.11   llm-01 llm-01.local
192.168.10.12   llm-02 llm-02.local
192.168.10.13   llm-03 llm-03.local
EOF

echo "✅ /etc/hosts updated"
echo "Test: ping llm-02 && ping 192.168.10.12"
