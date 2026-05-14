#!/bin/bash
# Start Exo node — llm-01 is the seed, llm-02/03 bootstrap from it

VENV="$HOME/exo-venv"
HOSTNAME=$(hostname -s)

if [ "$HOSTNAME" = "llm-01" ]; then
    "$VENV/bin/exo" --api-port 5678 --libp2p-port 5679
else
    "$VENV/bin/exo" --api-port 5678 --libp2p-port 5679 \
        --bootstrap-peers /ip4/192.168.10.11/tcp/5679
fi
