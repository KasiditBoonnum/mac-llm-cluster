// Poll queue manager for status and tok/s
setInterval(async () => {
    try {
        const queueResp = await fetch('http://llm-01.local:8080/queue/status');
        const queueData = await queueResp.json();

        const statusDiv = document.getElementById('cluster-status');
        if (statusDiv) {
            statusDiv.innerHTML = `
                Mode: ${queueData.mode.toUpperCase()} |
                Queue: ${queueData.queue_length} |
                Active: ${queueData.active_tasks} |
                Node3: ${queueData.node3_model} |
                Exo: ${queueData.exo_loaded ? 'LOADED' : 'OFF'}
            `;
        }

        const taskId = window._currentTaskId;
        if (taskId) {
            const taskResp = await fetch(`http://llm-01.local:8080/tasks/${taskId}`);
            const taskData = await taskResp.json();

            if (taskData.tokens_per_second) {
                const tokDiv = document.getElementById('tokens-per-second');
                if (tokDiv) {
                    tokDiv.textContent = `${taskData.tokens_per_second.toFixed(1)} tok/s`;
                }
            }
        }
    } catch (error) {
        console.error('Queue status error:', error);
    }
}, 1000);
