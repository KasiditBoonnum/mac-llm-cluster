#!/bin/bash
# exo-roll-start — Places the exo model instance and fires a priming inference
# request that triggers a full reload cycle, leaving the model fully operational
# within ~60s after completion.

set -euo pipefail

BASE_URL="http://localhost:5678"
MODEL="mlx-community/Qwen3.6-35B-A3B-8bit"
MAX_WAIT=300
INTERVAL=30

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}${*}${RESET}"; }
success() { echo -e "${GREEN}✅ ${*}${RESET}"; }
error()   { echo -e "${RED}❌ ${*}${RESET}" >&2; }

echo -e "\n${BOLD}=== Exo Model CLI ===${RESET}\n"
info "Model: $MODEL"
info "Start: roll start"
echo ""

# ── API check ─────────────────────────────────────────────────────────────────
if ! curl -sf "$BASE_URL/v1/models" &>/dev/null; then
    error "Exo API not reachable at $BASE_URL — is exo running?"
    exit 1
fi

# ── Check if already responding ───────────────────────────────────────────────
_is_responding() {
    local resp
    resp=$(curl -s --max-time 20 "$BASE_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}" \
        2>/dev/null || true)
    echo "$resp" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = (d.get('choices') or [{}])[0].get('message', {})
    content = msg.get('content') or msg.get('reasoning_content') or ''
    sys.exit(0 if content.strip() else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null
}

info "Checking if model is already loaded..."
if _is_responding; then
    success "Model already loaded — proceeding to roll start"
else
    # ── Place instance ─────────────────────────────────────────────────────────
    info "Placing model instance across cluster nodes..."
    curl -s --max-time 30 -X POST "$BASE_URL/place_instance" \
        -H "Content-Type: application/json" \
        -d "{\"model_id\":\"$MODEL\",\"sharding\":\"Pipeline\",\"instance_meta\":\"MlxRing\",\"min_nodes\":1}" \
        > /dev/null 2>&1 || true

    info "Loading model shards across nodes (~30s)..."
    echo ""

    elapsed=0
    while true; do
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))

        if _is_responding; then
            success "Model loaded and ready (${elapsed}s)"
            break
        fi

        info "[${elapsed}s] still loading..."

        if (( elapsed >= MAX_WAIT )); then
            error "Timed out after ${MAX_WAIT}s — model did not load."
            exit 1
        fi
    done
fi

# ── Priming inference ─────────────────────────────────────────────────────────
echo ""
echo -e "\n${BOLD}Roll start — $MODEL${RESET}"
info "Sending short inference request (max 50 tokens)..."
echo ""

curl -s --max-time 60 "$BASE_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Say hello in one sentence.\"}],
        \"max_tokens\": 50
    }" > /dev/null 2>&1 || true

echo "Model will be fully operational within 60s after this message."
