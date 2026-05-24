#!/bin/bash
# exo-unload — Delete the active model instance via the exo API (clean GPU unload)
# Usage: bash exo-unload.sh [model-id]

set -euo pipefail

BASE_URL="http://localhost:5678"
MODEL="${1:-mlx-community/Qwen3.6-35B-A3B-8bit}"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}${*}${RESET}"; }
success() { echo -e "${GREEN}✅ ${*}${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  ${*}${RESET}"; }
error()   { echo -e "${RED}❌ ${*}${RESET}" >&2; }

echo -e "\n${BOLD}=== Exo Unload ===${RESET}\n"
info "Model: $MODEL"
echo ""

# ── Resolve instance ID ───────────────────────────────────────────────────────
info "Resolving instance ID..."
ENCODED_MODEL=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$MODEL")

INSTANCE_ID=$(curl -s --max-time 10 \
    "$BASE_URL/instance/previews?model_id=${ENCODED_MODEL}&sharding=Pipeline&instance_meta=MlxRing" \
    2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for preview in d.get('previews', []):
        instance = preview.get('instance') or {}
        for key, val in instance.items():
            if isinstance(val, dict) and 'instanceId' in val:
                print(val['instanceId'])
                sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null || true)

if [[ -z "$INSTANCE_ID" ]]; then
    error "Could not resolve instance ID — is the model loaded?"
    echo "  Check: curl -s http://localhost:5678/instance/placement?model_id=..."
    exit 1
fi

success "Instance ID: $INSTANCE_ID"

# ── Delete instance ───────────────────────────────────────────────────────────
info "Sending DELETE request to exo API..."
DEL_RESP=$(curl -s --max-time 15 -X DELETE \
    "$BASE_URL/instance/$INSTANCE_ID" \
    -H "Content-Type: application/json" \
    2>/dev/null || true)

echo "$DEL_RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('message') or d.get('detail') or str(d)
    print(msg)
    sys.exit(0 if 'Command received' in msg or 'deleted' in msg.lower() else 1)
except Exception:
    print(sys.stdin.read() if False else repr(sys.argv))
    sys.exit(1)
" 2>/dev/null && success "Instance deleted — model unloaded from GPU" || {
    warn "Unexpected response: $DEL_RESP"
    exit 1
}
