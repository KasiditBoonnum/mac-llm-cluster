#!/usr/bin/env python3
"""Automated code reviewer using local LLM"""

import requests
import argparse
import subprocess
from pathlib import Path

OLLAMA_URL = "http://llm-01.local:11434"
MODEL = "deepseek-coder-v2:33b-instruct-q4_K_M"  # Use code model on node 3


def review_file(path: str) -> str:
    code = Path(path).read_text(errors='ignore')
    resp = requests.post(f"{OLLAMA_URL}/api/generate",
        json={"model": MODEL,
              "prompt": f"Review this code for bugs, security issues, and improvements. Be concise.\n\n```\n{code}\n```",
              "stream": False},
        timeout=120)
    return resp.json().get("response", "") if resp.status_code == 200 else "Review failed"


def review_diff() -> str:
    try:
        diff = subprocess.check_output(["git", "diff", "--cached"], text=True)
        if not diff.strip():
            diff = subprocess.check_output(["git", "diff", "HEAD~1"], text=True)
    except Exception:
        return "Not a git repo"

    resp = requests.post(f"{OLLAMA_URL}/api/generate",
        json={"model": MODEL,
              "prompt": f"Review this git diff for bugs and issues:\n\n{diff[:3000]}",
              "stream": False},
        timeout=120)
    return resp.json().get("response", "") if resp.status_code == 200 else "Review failed"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="File to review")
    parser.add_argument("--diff", action="store_true", help="Review git diff")
    args = parser.parse_args()

    if args.file:
        print(review_file(args.file))
    elif args.diff:
        print(review_diff())
    else:
        parser.print_help()
