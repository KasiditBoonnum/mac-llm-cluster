#!/bin/bash
# exo-model.sh — Select, test, and unload exo models from the terminal
#
# Usage:
#   bash exo-model.sh                          # interactive: pick model + test
#   bash exo-model.sh --list                   # list available models
#   bash exo-model.sh -m <model-id>            # select model, then prompt for test
#   bash exo-model.sh -m <model-id> --test quick
#   bash exo-model.sh -m <model-id> --test stress
#   bash exo-model.sh -m <model-id> --test token-stress
#   bash exo-model.sh -m <model-id> --test custom --prompt "Your prompt" --max-tokens 200
#   bash exo-model.sh --unload                 # stop exo on all nodes (unloads GPU)
#   bash exo-model.sh -m <model-id> --test quick --unload  # test then unload

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BASE_URL="http://localhost:5678"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${*}${RESET}"; }
success() { echo -e "${GREEN}✅ ${*}${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  ${*}${RESET}"; }
error()   { echo -e "${RED}❌ ${*}${RESET}" >&2; }
header()  { echo -e "\n${BOLD}${*}${RESET}"; }

# ── Defaults ──────────────────────────────────────────────────────────────────
MODEL=""
TEST_TYPE=""
CUSTOM_PROMPT=""
MAX_TOKENS=""
DO_UNLOAD=false
LIST_ONLY=false

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}exo-model.sh${RESET} — Select, test, and unload exo models

${BOLD}Usage:${RESET}
  bash exo-model.sh [options]

${BOLD}Options:${RESET}
  -m, --model <id>        Model ID to use (interactive picker if omitted)
  -t, --test <type>       Test type: quick | stress | token-stress | custom
      --prompt <text>     Prompt text (required for --test custom)
      --max-tokens <n>    Max tokens override
      --unload            Unload model from GPU after test (stops exo on all nodes)
      --list              List available models and exit
  -h, --help              Show this help

${BOLD}Examples:${RESET}
  bash exo-model.sh                                              # fully interactive
  bash exo-model.sh --list                                       # list models
  bash exo-model.sh -m mlx-community/Qwen3.6-35B-A3B-8bit --test quick
  bash exo-model.sh -m mlx-community/Qwen3.6-35B-A3B-8bit --test stress
  bash exo-model.sh -m mlx-community/Qwen3.6-35B-A3B-8bit --test token-stress
  bash exo-model.sh -m mlx-community/Qwen3.6-35B-A3B-8bit \\
      --test custom --prompt "Explain quantum computing" --max-tokens 300
  bash exo-model.sh -m mlx-community/Qwen3.6-35B-A3B-8bit --test quick --unload
  bash exo-model.sh --unload                                     # just unload
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model)       MODEL="$2";         shift 2 ;;
        -t|--test)        TEST_TYPE="$2";     shift 2 ;;
        --prompt)         CUSTOM_PROMPT="$2"; shift 2 ;;
        --max-tokens)     MAX_TOKENS="$2";    shift 2 ;;
        --unload)         DO_UNLOAD=true;     shift ;;
        --list)           LIST_ONLY=true;     shift ;;
        -h|--help)        usage; exit 0 ;;
        *)                error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ── API check ─────────────────────────────────────────────────────────────────
check_api() {
    if ! curl -sf "$BASE_URL/v1/models" &>/dev/null; then
        error "Exo API not reachable at $BASE_URL"
        echo "  Is exo running? Try: bash $SCRIPT_DIR/restart-exo.sh"
        exit 1
    fi
}

# ── Model listing ─────────────────────────────────────────────────────────────
fetch_models() {
    curl -sf "$BASE_URL/v1/models" | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = [m['id'] for m in data.get('data', [])]
print('\n'.join(models))
"
}

list_models() {
    check_api
    header "Available models on exo cluster ($BASE_URL):"
    local models
    models=$(fetch_models)
    if [[ -z "$models" ]]; then
        warn "No models found. Open http://localhost:5678 to download a model."
        return 1
    fi
    local i=1
    while IFS= read -r m; do
        echo -e "  ${CYAN}[$i]${RESET} $m"
        ((i++))
    done <<< "$models"
    echo ""
}

# ── Interactive pickers ───────────────────────────────────────────────────────
pick_model_interactive() {
    header "Available models:"
    local models
    models=$(fetch_models)
    if [[ -z "$models" ]]; then
        warn "No models found. Open http://localhost:5678 and download a model first."
        exit 1
    fi

    local model_array=()
    local i=1
    while IFS= read -r m; do
        model_array+=("$m")
        echo -e "  ${CYAN}[$i]${RESET} $m"
        ((i++))
    done <<< "$models"

    echo ""
    local choice
    while true; do
        read -rp "Select model [1-${#model_array[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#model_array[@]} )); then
            MODEL="${model_array[$((choice-1))]}"
            break
        fi
        warn "Enter a number between 1 and ${#model_array[@]}"
    done
    success "Selected: $MODEL"
}

pick_test_interactive() {
    header "Select test type:"
    echo -e "  ${CYAN}[1]${RESET} quick        — short sanity check (~50 tokens, non-streaming)"
    echo -e "  ${CYAN}[2]${RESET} stress       — long narrative generation (up to 64K tokens, streaming)"
    echo -e "  ${CYAN}[3]${RESET} token-stress — throughput benchmark with progress bar (48K tokens)"
    echo -e "  ${CYAN}[4]${RESET} custom       — enter your own prompt"
    echo -e "  ${CYAN}[5]${RESET} skip         — no test (warmup only)"
    echo ""

    local choice
    while true; do
        read -rp "Select test [1-5]: " choice
        case "$choice" in
            1) TEST_TYPE="quick";        break ;;
            2) TEST_TYPE="stress";       break ;;
            3) TEST_TYPE="token-stress"; break ;;
            4) TEST_TYPE="custom";       break ;;
            5) TEST_TYPE="skip";         break ;;
            *) warn "Enter a number between 1 and 5" ;;
        esac
    done
}

# ── Warmup ────────────────────────────────────────────────────────────────────
warmup_model() {
    local model="$1"
    local max_wait=300
    local interval=5
    local elapsed=0

    info "Loading model — sending first request (may take 1-2 min to shard across nodes)..."

    while true; do
        local resp
        resp=$(curl -s --max-time 30 "$BASE_URL/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}" \
            2>/dev/null || true)

        if echo "$resp" | grep -q '"content"'; then
            success "Model loaded and ready (${elapsed}s)"
            return
        fi

        local reason
        reason=$(echo "$resp" | python3 -c \
            'import sys,json; d=json.load(sys.stdin); print(d.get("detail") or d.get("error",{}).get("message","not ready"))' \
            2>/dev/null || echo "no response")

        elapsed=$((elapsed + interval))
        info "[${elapsed}s] ${reason}"

        if (( elapsed >= max_wait )); then
            error "Timed out after ${max_wait}s — model did not load."
            echo "  Check exo is running: bash $SCRIPT_DIR/restart-exo.sh"
            echo "  Or open http://localhost:5678 and click Launch."
            exit 1
        fi

        sleep $interval
    done
}

# ── Test: quick ───────────────────────────────────────────────────────────────
run_quick_test() {
    local model="$1"
    local max_tok="${MAX_TOKENS:-50}"
    header "Quick test — $model"
    info "Sending short inference request (max $max_tok tokens)..."

    local resp
    resp=$(curl -sf "$BASE_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Briefly explain what a distributed LLM cluster is in 2-3 sentences.\"}],
            \"max_tokens\": $max_tok
        }" 2>/dev/null)

    echo ""
    echo "$resp" | python3 -c "
import sys, json
d = json.load(sys.stdin)
msg = d['choices'][0]['message']
content = msg.get('content') or msg.get('reasoning_content', '(thinking...)')
usage = d.get('usage', {})
print('Response:', content)
print()
print(f\"Tokens  prompt={usage.get('prompt_tokens','?')}  completion={usage.get('completion_tokens','?')}  total={usage.get('total_tokens','?')}\")
"
    echo ""
    success "Quick test complete"
}

# ── Test: stress ──────────────────────────────────────────────────────────────
run_stress_test() {
    local model="$1"
    local max_tok="${MAX_TOKENS:-64000}"
    header "Stress test — $model"
    info "Long-form generation, target ~$max_tok tokens (streaming). Press Ctrl+C to stop."
    echo ""

    curl -s "$BASE_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [
                {\"role\": \"system\", \"content\": \"You are a creative writing assistant. Write the entire response in one continuous output. Never stop mid-way, never ask the user to continue, never add part numbers. Write the full piece from start to finish.\"},
                {\"role\": \"user\", \"content\": \"Write a detailed 20,000-word epic sci-fi narrative set 200 years in the future. Cover multiple character perspectives — a soldier, a scientist, a politician, and an AI. Explore themes of humanity, survival, and technology. Be vivid and specific. Write continuously without stopping.\"}
            ],
            \"max_tokens\": $max_tok,
            \"stream\": true
        }" \
        --no-buffer | python3 -c "
import sys, json, time

start = time.time()
tokens = 0
thinking_tokens = 0
is_thinking = True
gen_start = None
last_update = start
UPDATE_INTERVAL = 5

print('=== Thinking... ===', flush=True)
for line in sys.stdin:
    line = line.strip()
    if line.startswith('data: ') and line != 'data: [DONE]':
        try:
            d = json.loads(line[6:])
            delta = d['choices'][0]['delta']
            content = delta.get('content')
            if content is None:
                thinking_tokens += 1
            else:
                if is_thinking:
                    think_time = time.time() - start
                    print(f'\n=== Done thinking ({thinking_tokens} tokens, {think_time:.1f}s) ===\n', flush=True)
                    is_thinking = False
                    gen_start = time.time()
                tokens += 1
                print(content, end='', flush=True)
                now = time.time()
                if now - last_update >= UPDATE_INTERVAL:
                    elapsed = now - gen_start
                    tps = tokens / elapsed if elapsed > 0 else 0
                    print(f'\n[{tokens:,} tokens | {tps:.1f} tok/s | {elapsed/60:.1f} min elapsed]', flush=True)
                    last_update = now
        except Exception:
            pass

elapsed = time.time() - start
gen_elapsed = (time.time() - gen_start) if gen_start else 0
tps = tokens / gen_elapsed if gen_elapsed > 0 else 0

print(f'\n\n=== Stress Test Results ===')
print(f'Total time:       {elapsed:.1f}s ({elapsed/60:.1f} min)')
print(f'Thinking tokens:  {thinking_tokens}')
print(f'Generated tokens: {tokens:,}')
print(f'Speed:            {tps:.1f} tok/s')
print(f'Est. KV cache:    ~{tokens * 1.97 / 1024:.1f} GB (FP16)')
"
    echo ""
    success "Stress test complete"
}

# ── Test: token-stress ────────────────────────────────────────────────────────
run_token_stress_test() {
    local model="$1"
    local target="${MAX_TOKENS:-48000}"
    header "Token stress test — $model"
    info "Throughput benchmark, target $target tokens (streaming)."
    echo ""

    curl -s "$BASE_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [
                {\"role\": \"system\", \"content\": \"You are a writing assistant. Write continuously without stopping or asking to continue.\"},
                {\"role\": \"user\", \"content\": \"Write an extremely detailed and comprehensive history of human civilization from 10,000 BC to 2025 AD. Cover every major civilization, empire, invention, war, cultural movement, and scientific discovery across all continents. Go into exhaustive detail for each era — do not summarize. Write continuously without stopping.\"}
            ],
            \"max_tokens\": $target,
            \"stream\": true,
            \"enable_thinking\": false,
            \"temperature\": 1.0
        }" \
        --no-buffer | python3 -c "
import sys, json, time

FILL = chr(35); EMPTY = chr(45)
target = $target
start = time.time()
tokens = 0
gen_start = None
last_update = start
UPDATE_INTERVAL = 5
checkpoints = {10000, 20000, 30000, 40000}

print(f'=== Token Stress Test: Target {target:,} tokens ===', flush=True)
print('Waiting for generation...', flush=True)

for line in sys.stdin:
    line = line.strip()
    if line.startswith('data: ') and line != 'data: [DONE]':
        try:
            d = json.loads(line[6:])
            content = d['choices'][0]['delta'].get('content')
            if content:
                if gen_start is None:
                    gen_start = time.time()
                    print('\n=== Generation started ===\n', flush=True)
                tokens += 1
                now = time.time()
                if now - last_update >= UPDATE_INTERVAL:
                    elapsed = now - gen_start
                    tps = tokens / elapsed if elapsed > 0 else 0
                    pct = (tokens / target) * 100
                    bars = int(pct / 2)
                    print(f'\r[{FILL*bars}{EMPTY*(50-bars)}] {pct:.1f}% | {tokens:,}/{target:,} | {tps:.1f} tok/s | {elapsed/60:.1f}m', end='', flush=True)
                    last_update = now
                if tokens in checkpoints:
                    checkpoints.discard(tokens)
                    elapsed = time.time() - gen_start
                    tps = tokens / elapsed
                    kv = tokens * 1.97 / 1024
                    print(f'\n\nCHECKPOINT {tokens//1000}K: {tps:.1f} tok/s | KV cache ~{kv:.1f} GB', flush=True)
        except Exception:
            pass

elapsed = time.time() - start
gen_elapsed = (time.time() - gen_start) if gen_start else 0
tps = tokens / gen_elapsed if gen_elapsed > 0 else 0
kv = tokens * 1.97 / 1024

print('\n\n' + '='*60)
print('=== TOKEN STRESS TEST RESULTS ===')
print('='*60)
print(f'Total time:        {elapsed:.1f}s ({elapsed/60:.1f} min)')
print(f'Tokens generated:  {tokens:,} / {target:,}')
print(f'Average speed:     {tps:.1f} tok/s')
print(f'Peak KV cache:     ~{kv:.1f} GB (FP16)')
print(f'Target reached:    {(tokens/target)*100:.1f}%')
print('='*60)
if tokens >= target:
    print('SUCCESS: Reached token target!')
elif tokens >= int(target * 0.95):
    print('CLOSE: Nearly reached target (>95%)')
else:
    print(f'INCOMPLETE: {tokens:,} / {target:,} tokens generated')
"
    echo ""
    success "Token stress test complete"
}

# ── Test: custom ──────────────────────────────────────────────────────────────
run_custom_test() {
    local model="$1"

    if [[ -z "$CUSTOM_PROMPT" ]]; then
        echo ""
        read -rp "Enter your prompt: " CUSTOM_PROMPT
    fi

    local max_tok="${MAX_TOKENS:-500}"
    local prompt_json
    prompt_json=$(python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))' <<< "$CUSTOM_PROMPT")

    header "Custom test — $model"
    info "Prompt: $CUSTOM_PROMPT"
    info "Max tokens: $max_tok"
    echo ""

    curl -s "$BASE_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [{\"role\": \"user\", \"content\": $prompt_json}],
            \"max_tokens\": $max_tok,
            \"stream\": true
        }" \
        --no-buffer | python3 -c "
import sys, json, time
start = time.time()
tokens = 0
for line in sys.stdin:
    line = line.strip()
    if line.startswith('data: ') and line != 'data: [DONE]':
        try:
            d = json.loads(line[6:])
            content = d['choices'][0]['delta'].get('content')
            if content:
                tokens += 1
                print(content, end='', flush=True)
        except Exception:
            pass
elapsed = time.time() - start
tps = tokens / elapsed if elapsed > 0 else 0
print(f'\n\n[{tokens} tokens | {tps:.1f} tok/s | {elapsed:.1f}s]')
"
    echo ""
    success "Custom test complete"
}

# ── Unload (stop exo on all nodes) ────────────────────────────────────────────
unload_model() {
    header "Unloading model — stopping exo on all nodes"
    warn "This stops the exo process on all 3 nodes, freeing GPU memory."
    echo "  Restart later with: bash $SCRIPT_DIR/restart-exo.sh"
    echo ""

    local confirm
    read -rp "Confirm unload? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; return; }

    echo ""
    info "Stopping llm-01 (local)..."
    launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null || true
    pkill -9 -f exo 2>/dev/null || true
    pkill -9 -f python3 2>/dev/null || true
    rm -f ~/.exo/exo.pid 2>/dev/null || true
    success "llm-01 stopped"

    info "Stopping llm-02..."
    if ssh -o ConnectTimeout=5 llm-02 \
        'launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null; pkill -9 -f exo 2>/dev/null; pkill -9 -f python3 2>/dev/null; rm -f ~/.exo/exo.pid 2>/dev/null; echo ok' 2>/dev/null | grep -q ok; then
        success "llm-02 stopped"
    else
        warn "llm-02: could not connect via SSH"
    fi

    info "Stopping llm-03..."
    if ssh -o ConnectTimeout=5 llm-03 \
        'launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null; pkill -9 -f exo 2>/dev/null; pkill -9 -f python3 2>/dev/null; rm -f ~/.exo/exo.pid 2>/dev/null; echo ok' 2>/dev/null | grep -q ok; then
        success "llm-03 stopped"
    else
        warn "llm-03: could not connect via SSH"
    fi

    echo ""
    success "Model unloaded — GPU memory freed on all nodes"
    echo "  Restart: bash $SCRIPT_DIR/restart-exo.sh"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "\n${BOLD}=== Exo Model CLI ===${RESET}"

    # Just unload, nothing else
    if $DO_UNLOAD && [[ -z "$MODEL" ]] && [[ -z "$TEST_TYPE" ]]; then
        unload_model
        exit 0
    fi

    # List only
    if $LIST_ONLY; then
        list_models
        exit 0
    fi

    # Check API reachable
    check_api

    # Pick model interactively if not given
    [[ -z "$MODEL" ]] && pick_model_interactive

    # Pick test interactively if not given
    [[ -z "$TEST_TYPE" ]] && pick_test_interactive

    echo ""
    info "Model: $MODEL"
    info "Test:  ${TEST_TYPE:-skip}"
    echo ""

    case "$TEST_TYPE" in
        quick)
            warmup_model "$MODEL"
            run_quick_test "$MODEL"
            ;;
        stress)
            warmup_model "$MODEL"
            run_stress_test "$MODEL"
            ;;
        token-stress)
            warmup_model "$MODEL"
            run_token_stress_test "$MODEL"
            ;;
        custom)
            warmup_model "$MODEL"
            run_custom_test "$MODEL"
            ;;
        skip|"")
            warmup_model "$MODEL"
            success "Model ready — no test run"
            ;;
        *)
            error "Unknown test type: $TEST_TYPE"
            echo "  Valid: quick | stress | token-stress | custom"
            exit 1
            ;;
    esac

    # Unload after test if requested
    if $DO_UNLOAD; then
        echo ""
        unload_model
    fi
}

main
