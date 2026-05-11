#!/bin/bash
# Test 10GbE network performance between nodes

brew install iperf3

echo "Starting iperf3 server on llm-02..."
ssh llm-02.local "iperf3 -s -D" 2>/dev/null || ssh 192.168.10.12 "iperf3 -s -D"

sleep 2

echo "Running throughput test (30s, 4 parallel streams)..."
iperf3 -c llm-02.local -t 30 -P 4 || iperf3 -c 192.168.10.12 -t 30 -P 4

echo ""
echo "Expected: 9.0 - 9.5 Gbps"
echo "Latency test:"
ping -c 10 llm-02.local || ping -c 10 192.168.10.12
