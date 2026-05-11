#!/bin/bash
# Enable jumbo frames (MTU 9000)

INTERFACE=$(route get default | grep interface | awk '{print $2}')
sudo ifconfig "$INTERFACE" mtu 9000

echo "✅ MTU set to 9000 on $INTERFACE"
ifconfig "$INTERFACE" | grep mtu
