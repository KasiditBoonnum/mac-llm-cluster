#!/bin/bash
# Apply patches to exo source to fix upstream bugs

SRC="$HOME/exo-source"

if [ ! -d "$SRC" ]; then
    echo "ERROR: exo source not found at $SRC"
    exit 1
fi

echo "Ensuring mlx and mlx-lm are installed and up to date..."
"$HOME/exo-venv/bin/pip" install --upgrade mlx mlx-lm -q

echo "Patching placement.py: handle missing instance gracefully..."
sed -i '' '/raise ValueError.*Instance.*not found/c\    return target_instances' \
    "$SRC/src/exo/master/placement.py"

echo "Patching constants.py: increase instance retry limit for large model downloads..."
sed -i '' 's/EXO_MAX_INSTANCE_RETRIES = 5/EXO_MAX_INSTANCE_RETRIES = 50000/' \
    "$SRC/src/exo/shared/constants.py"

echo "All patches applied"
