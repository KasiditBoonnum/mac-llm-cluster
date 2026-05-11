#!/usr/bin/env python3
"""Node 3 model switcher - Qwen <-> DeepSeek"""

import requests
import time
import argparse

NODE3_URL = "http://llm-03.local:11435"
QWEN_MODEL = "qwen2.5:32b-instruct-q4_K_M"
DEEPSEEK_MODEL = "deepseek-coder-v2:33b-instruct-q4_K_M"


def switch_to(model: str, from_model: str):
    print(f"Unloading {from_model}...")
    requests.post(f"{NODE3_URL}/api/generate",
        json={"model": from_model, "prompt": "", "keep_alive": 0}, timeout=15)
    time.sleep(3)
    print(f"Loading {model}...")
    requests.post(f"{NODE3_URL}/api/generate",
        json={"model": model, "prompt": "", "keep_alive": -1}, timeout=60)
    print(f"✅ Switched to {model}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("target", choices=["qwen", "deepseek"])
    args = parser.parse_args()

    if args.target == "deepseek":
        switch_to(DEEPSEEK_MODEL, QWEN_MODEL)
    else:
        switch_to(QWEN_MODEL, DEEPSEEK_MODEL)
