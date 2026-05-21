#!/bin/bash
# Restart exo on all 3 nodes (kill + rm pid + relaunch)

launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null
pkill -9 -f exo
rm -f ~/.exo/exo.pid
sleep 2
nohup bash ~/mac-llm-cluster/scripts/exo/start-exo.sh > /tmp/exo.log 2>&1 &

ssh llm-02 'launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null; pkill -9 -f exo; rm -f ~/.exo/exo.pid; sleep 2; nohup bash ~/mac-llm-cluster/scripts/exo/start-exo.sh > /tmp/exo.log 2>&1 &'
ssh llm-03 'launchctl unload ~/Library/LaunchAgents/com.llm.exo.plist 2>/dev/null; pkill -9 -f exo; rm -f ~/.exo/exo.pid; sleep 2; nohup bash ~/mac-llm-cluster/scripts/exo/start-exo.sh > /tmp/exo.log 2>&1 &'

echo "Done — open http://localhost:5678 and click Launch"
