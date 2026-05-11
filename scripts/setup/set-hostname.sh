#!/bin/bash
# Set hostname for cluster node

echo "Select node number:"
echo "  1) llm-01 (Primary - Grafana, Nginx, Queue)"
echo "  2) llm-02 (Inference)"
echo "  3) llm-03 (Inference + Dynamic Switching)"
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        sudo scutil --set HostName llm-01
        sudo scutil --set LocalHostName llm-01
        sudo scutil --set ComputerName "LLM Node 01 Primary"
        echo "✅ Configured as llm-01 (Primary)"
        ;;
    2)
        sudo scutil --set HostName llm-02
        sudo scutil --set LocalHostName llm-02
        sudo scutil --set ComputerName "LLM Node 02 Inference"
        echo "✅ Configured as llm-02 (Inference)"
        ;;
    3)
        sudo scutil --set HostName llm-03
        sudo scutil --set LocalHostName llm-03
        sudo scutil --set ComputerName "LLM Node 03 Dynamic"
        echo "✅ Configured as llm-03 (Dynamic Switching)"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo "Hostname: $(hostname)"
echo "Test: ping $(hostname).local"
