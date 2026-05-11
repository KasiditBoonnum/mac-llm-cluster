#!/bin/bash
# Install Prometheus on Node 1

brew install prometheus

cat > /opt/homebrew/etc/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node1-system'
    static_configs:
      - targets: ['llm-01.local:9100']
        labels: {instance: 'llm-01', node: 'node1'}
  - job_name: 'node1-mac'
    static_configs:
      - targets: ['llm-01.local:9101']
        labels: {instance: 'llm-01', node: 'node1'}

  - job_name: 'node2-system'
    static_configs:
      - targets: ['llm-02.local:9100']
        labels: {instance: 'llm-02', node: 'node2'}
  - job_name: 'node2-mac'
    static_configs:
      - targets: ['llm-02.local:9101']
        labels: {instance: 'llm-02', node: 'node2'}

  - job_name: 'node3-system'
    static_configs:
      - targets: ['llm-03.local:9100']
        labels: {instance: 'llm-03', node: 'node3'}
  - job_name: 'node3-mac'
    static_configs:
      - targets: ['llm-03.local:9101']
        labels: {instance: 'llm-03', node: 'node3'}

  - job_name: 'inference'
    static_configs:
      - targets: ['llm-01.local:9102', 'llm-02.local:9102', 'llm-03.local:9102']
EOF

brew services start prometheus

echo "✅ Prometheus running on port 9090"
open http://llm-01.local:9090
