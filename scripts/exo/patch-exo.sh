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

echo "Patching cache.py: make deepseek_v4 import optional..."
python3 << 'PYEOF'
import os
filepath = os.path.expanduser("~/exo-source/src/exo/worker/engines/mlx/cache.py")
with open(filepath, "r") as f:
    content = f.read()
old = """from mlx_lm.models.deepseek_v4 import (
    DeepseekV4Cache,
)
from mlx_lm.models.deepseek_v4 import (
    _CompressorBranch as CompressorBranch,  # type: ignore
)"""
new = """try:
    from mlx_lm.models.deepseek_v4 import (
        DeepseekV4Cache,
    )
    from mlx_lm.models.deepseek_v4 import (
        _CompressorBranch as CompressorBranch,  # type: ignore
    )
except ImportError:
    class DeepseekV4Cache:  # type: ignore
        pass
    class CompressorBranch:  # type: ignore
        pass"""
if old in content:
    content = content.replace(old, new)
    with open(filepath, "w") as f:
        f.write(content)
    print("Patched cache.py successfully")
else:
    print("cache.py already patched or different version")
PYEOF

echo "All patches applied"
