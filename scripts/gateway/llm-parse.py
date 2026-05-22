#!/usr/bin/env python3
"""Pipe curl /v1/chat/completions output through this to pretty-print the reply and stats."""
import sys, json

data = json.loads(sys.stdin.read(), strict=False)
print(data["choices"][0]["message"]["content"])
s = data.get("_stats")
if s:
    print(f"\n{'─'*50}")
    print(f"model      : {s['model']}")
    print(f"prompt     : {s['prompt_tokens']} tok")
    print(f"completion : {s['completion_tokens']} tok")
    print(f"total      : {s['total_tokens']} tok")
    print(f"time       : {s['time_s']}s")
    print(f"speed      : {s['tok_s']} tok/s")
