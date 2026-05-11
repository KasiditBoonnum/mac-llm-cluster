#!/bin/bash
# Configure static IP - do this via System Settings on macOS
# System Settings → Network → Ethernet → Details → TCP/IP → Configure IPv4: Manually

echo "Static IP configuration must be done via macOS System Settings:"
echo ""
echo "  System Settings → Network → Ethernet → Details → TCP/IP"
echo "  Configure IPv4: Manually"
echo ""
echo "  Node assignments:"
echo "    llm-01:  192.168.10.11 / 255.255.255.0 / Gateway: 192.168.10.1"
echo "    llm-02:  192.168.10.12 / 255.255.255.0 / Gateway: 192.168.10.1"
echo "    llm-03:  192.168.10.13 / 255.255.255.0 / Gateway: 192.168.10.1"
echo ""
echo "DNS: 1.1.1.1, 8.8.8.8"
