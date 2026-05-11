#!/usr/bin/env python3
"""Scheduled report generator - daily cluster status report"""

import requests
import time
from datetime import datetime
from pathlib import Path
import subprocess

OLLAMA_URL = "http://llm-01.local:11434"
MODEL = "phi4:14b-q5_K_M"
QUEUE_URL = "http://llm-01.local:8080"
OUTPUT_DIR = Path.home() / "mac-llm-cluster/logs/reports"


def gather_context() -> str:
    lines = [f"Date: {datetime.now()}"]
    try:
        q = requests.get(f"{QUEUE_URL}/queue/status", timeout=3).json()
        lines.append(f"Queue mode: {q['mode']}, node3: {q['node3_model']}, exo: {q['exo_loaded']}")
    except Exception:
        lines.append("Queue: offline")
    try:
        disk = subprocess.check_output(["df", "-h", "/"], text=True).splitlines()[-1]
        lines.append(f"Disk: {disk}")
    except Exception:
        pass
    return '\n'.join(lines)


def generate_report():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    context = gather_context()
    try:
        resp = requests.post(f"{OLLAMA_URL}/api/generate",
            json={"model": MODEL,
                  "prompt": f"Write a brief daily cluster status report:\n\n{context}",
                  "stream": False},
            timeout=60)
        report = resp.json().get("response", "No response") if resp.status_code == 200 else "LLM unavailable"
    except Exception as e:
        report = f"Error: {e}"

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output = f"=== Daily Report {datetime.now()} ===\n\n{report}"
    (OUTPUT_DIR / f"report-{timestamp}.txt").write_text(output)
    print(f"Report saved: report-{timestamp}.txt")


if __name__ == "__main__":
    generate_report()
