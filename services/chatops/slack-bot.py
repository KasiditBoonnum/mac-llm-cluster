#!/usr/bin/env python3
"""Slack Bot for LLM Cluster"""

from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
import requests
import os

app = App(token=os.getenv("SLACK_BOT_TOKEN"))
QUEUE_URL = "http://llm-01.local:8080"


@app.message("!ask")
def handle_ask(message, say):
    question = message['text'].replace("!ask", "").strip()
    if not question:
        say("Usage: !ask <your question>")
        return

    say(f"🤔 Processing: {question[:50]}...")
    try:
        resp = requests.post(f"{QUEUE_URL}/v1/chat/completions",
            json={"model": "qwen2.5:32b-instruct-q4_K_M", "prompt": question},
            timeout=60)
        if resp.status_code == 200:
            task_id = resp.json().get("task_id")
            say(f"Queued (task: {task_id[:8]}...)")
    except Exception as e:
        say(f"❌ Error: {str(e)}")


@app.message("!status")
def handle_status(message, say):
    try:
        resp = requests.get(f"{QUEUE_URL}/queue/status", timeout=5)
        d = resp.json()
        say(f"✅ Cluster OK | Mode: {d['mode']} | Queue: {d['queue_length']}")
    except Exception:
        say("❌ Cluster offline")


if __name__ == "__main__":
    token = os.getenv("SLACK_APP_TOKEN")
    if not token:
        print("❌ Set SLACK_APP_TOKEN and SLACK_BOT_TOKEN")
        exit(1)
    SocketModeHandler(app, token).start()
