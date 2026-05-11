#!/usr/bin/env python3
"""Inference metrics exporter - tracks tokens/second per node"""

from prometheus_client import start_http_server, Gauge, Counter
import requests
import time

tokens_per_second = Gauge('llm_tokens_per_second', 'Inference speed', ['node', 'model'])
total_requests = Counter('llm_total_requests', 'Total inference requests', ['node'])
active_requests = Gauge('llm_active_requests', 'Active inference requests', ['node'])

OLLAMA_NODES = {
    'llm-01': 'http://llm-01.local:11434',
    'llm-02': 'http://llm-02.local:11434',
    'llm-03': 'http://llm-03.local:11435',
}

def collect_ollama_metrics():
    for node, url in OLLAMA_NODES.items():
        try:
            resp = requests.get(f"{url}/api/ps", timeout=3)
            if resp.status_code == 200:
                data = resp.json()
                models = data.get('models', [])
                active_requests.labels(node=node).set(len(models))
                for m in models:
                    model_name = m.get('name', 'unknown')
                    # Ollama doesn't expose tok/s directly; placeholder
                    tokens_per_second.labels(node=node, model=model_name).set(0)
        except Exception:
            active_requests.labels(node=node).set(0)

if __name__ == '__main__':
    start_http_server(9102)
    print("✅ Inference Metrics Exporter on port 9102")
    while True:
        collect_ollama_metrics()
        time.sleep(15)
