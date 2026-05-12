#!/usr/bin/env python3
"""Mac-specific metrics exporter - CPU, GPU, RAM, Power"""

from prometheus_client import start_http_server, Gauge
import subprocess
import re
import time
import psutil

cpu_usage   = Gauge('mac_cpu_usage_percent',    'CPU usage per core', ['core'])
gpu_usage   = Gauge('mac_gpu_usage_percent',    'GPU active residency %')
gpu_power   = Gauge('mac_gpu_power_mw',         'GPU power in mW')
combined_power = Gauge('mac_combined_power_mw', 'Combined CPU+GPU+ANE power in mW')
memory_used    = Gauge('mac_memory_used_bytes', 'Memory used bytes')
memory_total   = Gauge('mac_memory_total_bytes','Total memory bytes')
memory_percent = Gauge('mac_memory_usage_percent', 'Memory usage %')

def get_cpu_usage():
    for i, usage in enumerate(psutil.cpu_percent(interval=1, percpu=True)):
        cpu_usage.labels(core=f'cpu{i}').set(usage)

def get_powermetrics():
    try:
        result = subprocess.run(
            ['sudo', 'powermetrics', '--samplers', 'cpu_power,gpu_power', '-i1', '-n1'],
            capture_output=True, text=True, timeout=10
        )
        for line in result.stdout.split('\n'):
            # GPU usage: "GPU HW active residency: 24.46%"
            if re.search(r'GPU\s+(?:HW\s+)?active\s+residency', line, re.IGNORECASE):
                m = re.search(r'(\d+\.?\d*)%', line)
                if m:
                    gpu_usage.set(float(m.group(1)))
            # GPU power: "GPU Power: 61 mW"
            if re.match(r'GPU Power:', line):
                m = re.search(r'(\d+\.?\d*)\s*mW', line)
                if m:
                    gpu_power.set(float(m.group(1)))
            # Combined power: "Combined Power (CPU + GPU + ANE): 1516 mW"
            if 'Combined Power' in line:
                m = re.search(r'(\d+\.?\d*)\s*mW', line)
                if m:
                    combined_power.set(float(m.group(1)))
    except Exception:
        pass

def get_memory():
    mem = psutil.virtual_memory()
    memory_total.set(mem.total)
    memory_used.set(mem.used)
    memory_percent.set(mem.percent)

if __name__ == '__main__':
    start_http_server(9101)
    print("Mac Metrics Exporter on port 9101")
    while True:
        get_cpu_usage()
        get_powermetrics()
        get_memory()
        time.sleep(15)
