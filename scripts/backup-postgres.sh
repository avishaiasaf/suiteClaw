#!/usr/bin/env bash
# Backup all PostgreSQL databases
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "=== PostgreSQL Backup: $TIMESTAMP ==="

for DB in n8n memory audit; do
    BACKUP_FILE="${BACKUP_DIR}/${DB}_${TIMESTAMP}.sql.gz"
    echo "Backing up $DB..."
    docker compose exec -T postgres pg_dump -U postgres -d "$DB" | gzip > "$BACKUP_FILE"
    SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
    echo "  -> $BACKUP_FILE ($SIZE)"
done

# Rotate backups older than 30 days
echo ""
echo "Rotating backups older than 30 days..."
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +30 -delete -print | while read -r f; do
    echo "  Deleted: $f"
done

echo ""
echo "=== Backup complete ==="
