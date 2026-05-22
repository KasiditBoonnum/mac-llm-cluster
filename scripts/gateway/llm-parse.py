#!/usr/bin/env python3
"""Pipe curl /v1/chat/completions output through this to pretty-print the reply and stats."""
import sys, json

data = json.loads(sys.stdin.read(), strict=False)
s = data.get("_stats")

if s and s.get("logs"):
    print(f"{'─'*50}")
    for line in s["logs"]:
        print("[5] Done" if line.startswith("[5]") else line)
    print(f"{'─'*50}")

print(data["choices"][0]["message"]["content"])

if s:
    print(f"{'─'*50}")
    print(f"prompt={s['prompt_tokens']} tok | completion={s['completion_tokens']} tok | total={s['total_tokens']} tok | time={s['time_s']}s | speed={s['tok_s']} tok/s")
