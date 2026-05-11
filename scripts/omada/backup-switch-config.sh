#!/bin/bash
# Backup Omada switch configuration

BACKUP_DIR="$HOME/mac-llm-cluster/backups/omada"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Export via Omada API
docker exec omada-controller tar -czf /tmp/omada-backup.tar.gz \
    /opt/tplink/EAPController/data/

docker cp omada-controller:/tmp/omada-backup.tar.gz \
    "$BACKUP_DIR/omada-backup-$DATE.tar.gz"

echo "✅ Backup saved: $BACKUP_DIR/omada-backup-$DATE.tar.gz"

# Keep only last 5 backups
ls -t "$BACKUP_DIR"/*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null || true
