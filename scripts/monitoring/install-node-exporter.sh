#!/bin/bash
# Install Node Exporter on all nodes

eval "$(/opt/homebrew/bin/brew shellenv)"

brew install node_exporter
brew services start node_exporter

echo "Node Exporter running on port 9100"
sleep 2
curl -s http://localhost:9100/metrics | head -5
