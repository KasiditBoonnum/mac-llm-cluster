#!/bin/bash
# Start Exo node — llm-01 is the fixed head (lowest node-id wins master election)

VENV="$HOME/exo-venv"
HOSTNAME=$(hostname -s)

export PYTHONPATH="$VENV/lib/python3.13/site-packages${PYTHONPATH:+:$PYTHONPATH}"
source "$VENV/bin/activate"

# llm-01 gets node-id "000-llm-01" so it always wins the master election
if [ "$HOSTNAME" = "llm-01" ]; then
    exo --api-port 5678 --libp2p-port 5679 --node-id "000-llm-01"
else
    exo --api-port 5678 --libp2p-port 5679
fi
