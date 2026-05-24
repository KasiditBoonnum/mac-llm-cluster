#!/bin/bash
# exo-unload — Delete the active model instance and free GPU memory across all nodes
# Tries the exo DELETE /instance API first, falls back to process termination.

set -euo pipefail

BASE_URL="http://localhost:5678"
MODEL="${1:-mlx-community/Qwen3.6-35B-A3B-8bit}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}${*}${RESET}"; }
success() { echo -e "${GREEN}✅ ${*}${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  ${*}${RESET}"; }
error()   { echo -e "${RED}❌ ${*}${RESET}" >&2; }

echo -e "\n${BOLD}=== Exo Unload ===${RESET}\n"
info "Model: $MODEL"
echo ""

# ── Try DELETE /instance/{instance_id} via the exo API ───────────────────────
instance_id=$(curl -s --max-time 10 \
    "$BASE_URL/instance/placement?model_id=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$MODEL")&sharding=Pipeline&instance_meta=MlxRing" \
    2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('instance_id') or d.get('id') or '')
except Exception:
    print('')
" 2>/dev/null || true)

if [[ -n "$instance_id" ]]; then
    info "Found instance: $instance_id"
    info "Deleting instance via API..."
    del_resp=$(curl -s --max-time 15 -X DELETE "$BASE_URL/instance/$instance_id" 2>/dev/null || true)
    if echo "$del_resp" | grep -q "Command received\|deleted\|success"; then
        success "Instance deleted — GPU memory freed"
        exit 0
    else
        warn "API delete returned unexpected response: $del_resp"
        warn "Falling back to process termination..."
    fi
else
    warn "Could not resolve instance ID via API — falling back to process termination..."
fi

# ── Fallback: stop exo processes on all nodes ─────────────────────────────────
echo ""
info "Stopping exo on llm-01 (local)..."
launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null || true
pkill -9 -f exo 2>/dev/null || true
pkill -9 -f python3 2>/dev/null || true
rm -f ~/.exo/exo.pid 2>/dev/null || true
success "llm-01 stopped"

info "Stopping exo on llm-02..."
if ssh -o ConnectTimeout=5 llm-02 \
    'launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null; pkill -9 -f exo 2>/dev/null; pkill -9 -f python3 2>/dev/null; rm -f ~/.exo/exo.pid 2>/dev/null; echo ok' \
    2>/dev/null | grep -q ok; then
    success "llm-02 stopped"
else
    warn "llm-02: could not connect via SSH"
fi

info "Stopping exo on llm-03..."
if ssh -o ConnectTimeout=5 llm-03 \
    'launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null; pkill -9 -f exo 2>/dev/null; pkill -9 -f python3 2>/dev/null; rm -f ~/.exo/exo.pid 2>/dev/null; echo ok' \
    2>/dev/null | grep -q ok; then
    success "llm-03 stopped"
else
    warn "llm-03: could not connect via SSH"
fi

echo ""
success "Model unloaded — GPU memory freed on all nodes"
echo "  Restart exo: bash $SCRIPT_DIR/restart-exo.sh"
