#!/bin/bash
# Apply patches to exo source to fix upstream bugs

SRC="$HOME/exo-source"

if [ ! -d "$SRC" ]; then
    echo "ERROR: exo source not found at $SRC"
    exit 1
fi

echo "Patching placement.py: handle missing instance gracefully..."
sed -i '' '/raise ValueError.*Instance.*not found/c\    return target_instances' \
    "$SRC/src/exo/master/placement.py"

echo "All patches applied"
