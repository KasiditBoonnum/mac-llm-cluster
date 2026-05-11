#!/usr/bin/env python3
"""Exo cluster controller - load/unload distributed inference"""

import subprocess
import time
import requests
import argparse

EXO_PORT = 5678
COORDINATOR = f"llm-01.local:{EXO_PORT}"
WORKER_NODES = ["llm-02.local", "llm-03.local"]
MODEL = "Qwen/Qwen3-30B-A3B:q5_K_M"


def is_running():
    try:
        r = requests.get(f"http://llm-01.local:{EXO_PORT}/v1/models", timeout=3)
        return r.status_code == 200
    except Exception:
        return False


def load():
    if is_running():
        print("Exo already running")
        return
    print("Starting Exo coordinator on llm-01...")
    subprocess.Popen([
        "exo", "run",
        "--nodes", f"llm-01.local:{EXO_PORT},llm-02.local:{EXO_PORT},llm-03.local:{EXO_PORT}",
        "--model", MODEL,
        "--context-size", "65536",
        "--kv-cache-type", "q16_0",
        "--listen", f"0.0.0.0:{EXO_PORT}"
    ])
    for node in WORKER_NODES:
        print(f"Starting Exo worker on {node}...")
        subprocess.Popen(["ssh", node,
                          f"exo worker --coordinator {COORDINATOR} --listen 0.0.0.0:{EXO_PORT}"])
    print("Waiting for cluster to initialize...")
    time.sleep(20)
    print("✅ Exo cluster loaded" if is_running() else "❌ Exo failed to start")


def unload():
    subprocess.run(["pkill", "-f", "exo"])
    for node in WORKER_NODES:
        subprocess.run(["ssh", node, "pkill -f exo"])
    print("✅ Exo unloaded")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["load", "unload", "status"])
    args = parser.parse_args()

    if args.action == "load":
        load()
    elif args.action == "unload":
        unload()
    elif args.action == "status":
        print("Exo running" if is_running() else "Exo not running")
