#!/bin/bash
# Start Exo node — llm-01 is the seed, llm-02/03 bootstrap from it

VENV="$HOME/exo-venv"

source "$VENV/bin/activate"
exo --api-port 5678 --libp2p-port 5679
