#!/usr/bin/env bash
# Restore a PostgreSQL database from backup
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    echo "Example: $0 ./backups/audit_20260321_120000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Extract database name from filename (format: dbname_timestamp.sql.gz)
DB_NAME=$(basename "$BACKUP_FILE" | sed 's/_[0-9].*$//')

echo "WARNING: This will overwrite the '$DB_NAME' database!"
read -p "Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo "Restoring $DB_NAME from $BACKUP_FILE..."
gunzip -c "$BACKUP_FILE" | docker compose exec -T postgres psql -U postgres -d "$DB_NAME"

echo "=== Restore complete ==="
