#!/usr/bin/env python3
"""Continuous log analyzer - monitors logs and sends AI analysis"""

import time
import requests
import os
from pathlib import Path
from datetime import datetime

GATEWAY_URL = "http://localhost:8082"
MODEL = "phi4:latest"
LOG_FILES = ["/var/log/nginx/error.log", "/tmp/queue-manager.err"]
OUTPUT_DIR = Path.home() / "mac-llm-cluster/logs/analysis"
CHECK_INTERVAL = 3600  # 1 hour


def analyze_log(log_path: str) -> str:
    try:
        content = Path(log_path).read_text(errors='ignore')
        recent = '\n'.join(content.splitlines()[-50:])
        if not recent.strip():
            return ""
        resp = requests.post(f"{GATEWAY_URL}/v1/chat/completions",
            json={"model": MODEL,
                  "messages": [{"role": "user", "content": f"Summarize errors/warnings from these logs in 3 bullets:\n{recent}"}],
                  "use_rag": False,
                  "scrub_pii": False},
            headers={"Authorization": "Bearer sk-llm-cluster"},
            timeout=120)
        if resp.status_code == 200:
            return resp.json()["choices"][0]["message"]["content"]
        return ""
    except Exception as e:
        return f"Error analyzing {log_path}: {e}"


def run():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    while True:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_lines = [f"=== Log Analysis {datetime.now()} ===\n"]
        for log in LOG_FILES:
            if Path(log).exists():
                analysis = analyze_log(log)
                if analysis:
                    report_lines.append(f"\n--- {log} ---\n{analysis}")
        if len(report_lines) > 1:
            report = '\n'.join(report_lines)
            (OUTPUT_DIR / f"analysis-{timestamp}.txt").write_text(report)
            print(f"Analysis saved: analysis-{timestamp}.txt")
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    run()
