#!/bin/bash
# Docker resource configuration guide

NODE=$(hostname -s)

case $NODE in
    llm-01)
        echo "Node 1 (Primary) - Recommended Docker resources:"
        echo "  CPUs:   8"
        echo "  Memory: 16 GB"
        echo "  Disk:   100 GB"
        ;;
    llm-02)
        echo "Node 2 (Inference) - Recommended Docker resources:"
        echo "  CPUs:   4"
        echo "  Memory: 8 GB"
        echo "  Disk:   50 GB"
        ;;
    llm-03)
        echo "Node 3 (Dynamic) - Recommended Docker resources:"
        echo "  CPUs:   4"
        echo "  Memory: 8 GB"
        echo "  Disk:   50 GB"
        ;;
esac

echo ""
echo "Configure in: Docker Desktop → Settings → Resources → Advanced"
