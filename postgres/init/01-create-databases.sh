#!/bin/bash
set -e

# Read passwords from Docker secrets (mounted by docker-compose)
N8N_PW=$(cat /run/secrets/pg_n8n_password)
MEMORY_PW=$(cat /run/secrets/pg_memory_password)
AUDIT_PW=$(cat /run/secrets/pg_audit_password)

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER n8n WITH PASSWORD '$N8N_PW';
    CREATE DATABASE n8n OWNER n8n;

    CREATE USER memory_user WITH PASSWORD '$MEMORY_PW';
    CREATE DATABASE memory OWNER memory_user;

    CREATE USER audit_user WITH PASSWORD '$AUDIT_PW';
    CREATE DATABASE audit OWNER audit_user;

    GRANT CONNECT ON DATABASE n8n TO n8n;
    GRANT CONNECT ON DATABASE memory TO memory_user;
    GRANT CONNECT ON DATABASE audit TO audit_user;
EOSQL
