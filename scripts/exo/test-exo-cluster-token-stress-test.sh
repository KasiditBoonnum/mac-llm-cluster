#!/bin/bash

curl -s http://localhost:5678/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"mlx-community/Qwen3.6-35B-A3B-8bit","messages":[{"role":"system","content":"You are a creative writing assistant. Write the entire response in one continuous output without stopping, asking to continue, or adding part numbers."},{"role":"user","content":"Write an extremely detailed and comprehensive history of human civilization from 10,000 BC to 2025 AD. Cover every major civilization, empire, invention, war, cultural movement, scientific discovery, and political revolution. Include detailed descriptions of daily life, economics, religion, art, architecture, agriculture, trade routes, and technological development across all continents. Go into exhaustive detail for each era — do not summarize, expand on every topic as much as possible. Write continuously without stopping."}],"max_tokens":52000,"stream":true,"enable_thinking":false,"presence_penalty":0,"frequency_penalty":0,"temperature":1.0}' \
    --no-buffer | python3 -c "
import sys, json, time

FILL = chr(35)
EMPTY = chr(45)
start = time.time()
tokens = 0
chars = 0
gen_start = None
last_update = start
update_interval = 5
checkpoint_interval = 5000  # Checkpoint every 5k tokens

print('=== Token Stress Test: Target 48,000 tokens ===', flush=True)
print('Starting generation...\n', flush=True)

for line in sys.stdin:
    line = line.strip()
    if line.startswith('data: ') and line != 'data: [DONE]':
        try:
            d = json.loads(line[6:])
            delta = d['choices'][0]['delta']
            content = delta.get('content')

            if content:
                if gen_start is None:
                    gen_start = time.time()
                    print('=== Generation started ===\n', flush=True)

                tokens += 1
                chars += len(content)

                # Progress bar every 5 seconds
                now = time.time()
                if now - last_update >= update_interval:
                    elapsed = now - gen_start
                    tps = tokens / elapsed if elapsed > 0 else 0
                    progress = (tokens / 48000) * 100
                    bars = int(progress / 2)

                    print(f'\r[{FILL * bars}{EMPTY * (50-bars)}] {progress:.1f}% | {tokens:,} / 48,000 tokens | {tps:.1f} tok/s | {elapsed/60:.1f} min', end='', flush=True)
                    last_update = now

                # Checkpoint warnings
                if tokens in [10000, 20000, 30000, 40000]:
                    elapsed = time.time() - gen_start
                    tps = tokens / elapsed
                    kv_cache_gb = tokens * 1.97 / 1024
                    print(f'\n\nCHECKPOINT {tokens//1000}K: {tps:.1f} tok/s | KV cache: ~{kv_cache_gb:.1f} GB', flush=True)
        except Exception as e:
            pass

print('\n')
elapsed = time.time() - start
gen_elapsed = (time.time() - gen_start) if gen_start else 0
tps = tokens / gen_elapsed if gen_elapsed > 0 else 0
kv_cache_gb = tokens * 1.97 / 1024

print('\n' + '='*60)
print('=== STRESS TEST RESULTS ===')
print('='*60)
print(f'Total time:        {elapsed:.1f}s ({elapsed/60:.1f} minutes)')
print(f'Generation time:   {gen_elapsed:.1f}s')
print(f'Tokens generated:  {tokens:,}')
print(f'Characters:        {chars:,}')
print(f'Average speed:     {tps:.1f} tok/s')
print(f'Peak KV cache:     ~{kv_cache_gb:.1f} GB (FP16)')
print(f'Target reached:    {(tokens/48000)*100:.1f}%')
print('='*60)

if tokens >= 48000:
    print('✅ SUCCESS: Reached 48K token target!')
elif tokens >= 45000:
    print('⚠️  CLOSE: Nearly reached target')
else:
    print(f'❌ INCOMPLETE: Only generated {tokens:,} / 48,000 tokens')
"
