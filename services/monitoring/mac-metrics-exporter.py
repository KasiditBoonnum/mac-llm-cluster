#!/usr/bin/env python3
"""Mac-specific metrics exporter - CPU, GPU, RAM, Temperature"""

from prometheus_client import start_http_server, Gauge
import subprocess
import re
import time
import psutil

cpu_usage = Gauge('mac_cpu_usage_percent', 'CPU usage', ['core'])
cpu_temp = Gauge('mac_cpu_temperature_celsius', 'CPU temperature')
gpu_usage = Gauge('mac_gpu_usage_percent', 'GPU usage')
gpu_temp = Gauge('mac_gpu_temperature_celsius', 'GPU temperature')
memory_used = Gauge('mac_memory_used_bytes', 'Memory used')
memory_total = Gauge('mac_memory_total_bytes', 'Total memory')
memory_percent = Gauge('mac_memory_usage_percent', 'Memory usage %')

def get_cpu_usage():
    for i, usage in enumerate(psutil.cpu_percent(interval=1, percpu=True)):
        cpu_usage.labels(core=f'cpu{i}').set(usage)

def get_powermetrics_temps():
    try:
        result = subprocess.run(
            ['sudo', 'powermetrics', '--samplers', 'smc,gpu_power', '-i1', '-n1'],
            capture_output=True, text=True, timeout=8
        )
        for line in result.stdout.split('\n'):
            if 'CPU die temperature' in line:
                m = re.search(r'(\d+\.?\d*)\s*C', line)
                if m:
                    cpu_temp.set(float(m.group(1)))
            if 'GPU' in line and 'temperature' in line.lower():
                m = re.search(r'(\d+\.?\d*)\s*C', line)
                if m:
                    gpu_temp.set(float(m.group(1)))
            if 'GPU Active' in line:
                m = re.search(r'(\d+)%', line)
                if m:
                    gpu_usage.set(float(m.group(1)))
    except Exception:
        pass

def get_memory():
    mem = psutil.virtual_memory()
    memory_total.set(mem.total)
    memory_used.set(mem.used)
    memory_percent.set(mem.percent)

if __name__ == '__main__':
    start_http_server(9101)
    print("✅ Mac Metrics Exporter on port 9101")
    while True:
        get_cpu_usage()
        get_powermetrics_temps()
        get_memory()
        time.sleep(15)
