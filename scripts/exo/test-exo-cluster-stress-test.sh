#!/bin/bash
# Stress test Exo cluster with a long-form generation request

curl -s http://localhost:5678/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"mlx-community/Qwen3.6-35B-A3B-8bit","messages":[{"role":"user","content":"Write a 50,000 word epic narrative set in a world 15 years after WW3 ended. The war lasted 8 years (2032-2040) and devastated the planet. Requirements:\n\n1. STRUCTURE: Tell the story through 7 different character perspectives, each with distinct voices and backgrounds: a former soldier with PTSD, a child born during the war who knows nothing else, a scientist working on ecological restoration, a black market trader, a government official trying to rebuild society, a religious leader grappling with faith after genocide, and a AI researcher dealing with the ethical implications of autonomous weapons used in the war.\n\n2. SETTING DETAILS: Describe the physical scars - irradiated zones, collapsed megacities, refugee settlements, the \"Green Zones\" where nature is reclaiming ruins, underground bunker communities, and the heavily fortified \"Safe Cities\". Include specific details about how climate change accelerated during the war, new diseases, mutated wildlife, and technological regression in some areas vs advancement in others.\n\n3. PLOT COMPLEXITY: Weave together multiple storylines including: a conspiracy about what really started the war, the discovery of pre-war weapons caches that could reignite conflict, a pandemic emerging from war-damaged bioweapon facilities, political tensions between survivor factions, and a generation gap between those who remember the old world and those who don'\''t.\n\n4. TECHNICAL DEPTH: Include realistic details about post-war challenges: supply chain collapse, currency systems breakdown, energy grid restoration, water purification, food production in contaminated soil, medical care without pharmaceutical supply chains, and psychological trauma treatment.\n\n5. THEMES: Explore trauma and healing, the cycle of violence, environmental consequences, technological ethics, the fragility of civilization, hope vs despair, collective vs individual survival, and whether humanity deserves a second chance.\n\n6. STYLE: Use vivid sensory details, realistic dialogue with distinct character voices, avoid melodrama, include moral ambiguity, show don'\''t tell emotional states, and vary pacing between action sequences and introspective moments. Include journal entries, official documents, and intercepted communications as narrative devices.\n\nMake it feel lived-in and real, not like a Hollywood adaptation. Show the mundane struggles alongside the epic moments."}],"max_tokens":80000,"stream":true}' \
    --no-buffer | python3 -c "
import sys, json, time
start = time.time()
tokens = 0
thinking_tokens = 0
is_thinking = True
gen_start = None
word_count = 0
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
                word_count += len(content.split())
                print(content, end='', flush=True)
        except:
            pass
elapsed = time.time() - start
gen_elapsed = (time.time() - gen_start) if gen_start else 0
tps = tokens / gen_elapsed if gen_elapsed > 0 else 0
print(f'\n\n=== Stats ===')
print(f'Total time:       {elapsed:.1f}s')
print(f'Thinking tokens:  {thinking_tokens}')
print(f'Generated tokens: {tokens}')
print(f'Approx words:     {word_count}')
print(f'Generation speed: {tps:.1f} tok/s')
print(f'Word/token ratio: {word_count/tokens if tokens > 0 else 0:.2f}')
"
