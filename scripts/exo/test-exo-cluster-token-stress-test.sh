#!/bin/bash

curl -s http://localhost:5678/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"mlx-community/Qwen3.6-35B-A3B-8bit","messages":[{"role":"user","content":"Generate a comprehensive dataset of 2000 fictional product entries for an e-commerce database. Each entry must include:\n\n1. Product ID (sequential)\n2. Product name (creative, varied)\n3. Category (electronics, clothing, home, sports, books, toys, food, etc.)\n4. Price (realistic range $5-$5000)\n5. Description (50-80 words describing features, benefits, materials, use cases)\n6. Specifications (3-5 technical specs)\n7. Stock quantity\n8. Supplier name\n9. SKU code\n10. Tags (5-8 relevant keywords)\n\nFormat as JSON array. Make each product unique and realistic. Include diverse categories and price points. Vary the descriptions significantly - no repetitive templates. Generate all 2000 entries."}],"max_tokens":52000,"stream":true}' \
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
