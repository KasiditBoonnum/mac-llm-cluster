#!/bin/bash
# Restart exo on all 3 nodes
# Usage: bash restart-exo.sh        — kill and restart
#        bash restart-exo.sh -t     — terminate only (no restart)

TERMINATE_ONLY=false
[ "$1" = "-t" ] && TERMINATE_ONLY=true

kill_node() {
    local host=$1
    if [ "$host" = "local" ]; then
        sudo pkill -9 -f exo; sudo pkill -9 -f python3; rm -f ~/.exo/exo.pid
    else
        ssh "$host" 'sudo pkill -9 -f exo; sudo pkill -9 -f python3; rm -f ~/.exo/exo.pid'
    fi
}

echo "Stopping exo on all nodes..."
kill_node local
kill_node llm-02
kill_node llm-03

if $TERMINATE_ONLY; then
    echo "Done — exo stopped on all nodes"
    exit 0
fi

sleep 2
echo "Starting exo on all nodes..."
nohup bash ~/mac-llm-cluster/scripts/exo/start-exo.sh > /tmp/exo.log 2>&1 &
ssh llm-02 'nohup bash ~/mac-llm-cluster/scripts/exo/start-exo.sh > /tmp/exo.log 2>&1 &'
ssh llm-03 'nohup bash ~/mac-llm-cluster/scripts/exo/start-exo.sh > /tmp/exo.log 2>&1 &'
echo "Done — open http://localhost:5678 and click Launch"
