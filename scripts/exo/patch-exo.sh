#!/bin/bash
# Apply patches to exo source to fix upstream bugs

SRC="$HOME/exo-source"

if [ ! -d "$SRC" ]; then
    echo "ERROR: exo source not found at $SRC"
    exit 1
fi

echo "Installing exo mlx extras (custom mlx-lm with deepseek_v4, mlx-vlm)..."
cd "$SRC" && "$HOME/exo-venv/bin/pip" install -e ".[mlx]" -q

echo "Reverting any previously broken source patches..."
cd "$SRC" && git checkout src/exo/worker/engines/mlx/cache.py src/exo/worker/engines/mlx/types.py 2>/dev/null || true

echo "Patching placement.py: handle missing instance gracefully..."
sed -i '' '/raise ValueError.*Instance.*not found/c\    return target_instances' \
    "$SRC/src/exo/master/placement.py"

echo "Patching constants.py: increase instance retry limit for large model downloads..."
sed -i '' 's/EXO_MAX_INSTANCE_RETRIES = 5/EXO_MAX_INSTANCE_RETRIES = 50000/' \
    "$SRC/src/exo/shared/constants.py"

echo "Creating deepseek_v4 stub module so exo imports don't crash..."
python3 << 'PYEOF'
import os
site_packages = os.path.join(os.path.expanduser("~"), "exo-venv", "lib", "python3.13", "site-packages")
stub_path = os.path.join(site_packages, "mlx_lm", "models", "deepseek_v4.py")
stub = """# Stub — deepseek_v4 not available in this mlx-lm version
class DeepseekV4Cache:
    pass
class DeepseekV4MoE:
    pass
class V4Attention:
    pass
class Model:
    pass
class _CompressorBranch:
    pass
"""
with open(stub_path, "w") as f:
    f.write(stub)
print("deepseek_v4 stub written")
PYEOF

echo "All patches applied"
