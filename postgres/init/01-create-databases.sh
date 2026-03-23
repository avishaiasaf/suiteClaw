#!/bin/bash
set -e

# Create audit database for SOX-compliant logging
# OpenClaw uses its own SQLite for memory; PostgreSQL is for structured audit logs.

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER audit_user WITH PASSWORD '$AUDIT_DB_PASSWORD';
    CREATE DATABASE audit OWNER audit_user;
    GRANT CONNECT ON DATABASE audit TO audit_user;
EOSQL
