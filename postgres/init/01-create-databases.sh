#!/bin/bash
set -e

# Reads passwords from environment variables passed via docker-compose.yml.
# Docker secrets (/run/secrets/) are NOT readable by the postgres user during init,
# so we use env vars instead. These are only needed once — PG stores hashed passwords internally.

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER n8n WITH PASSWORD '$N8N_DB_PASSWORD';
    CREATE DATABASE n8n OWNER n8n;

    CREATE USER memory_user WITH PASSWORD '$MEMORY_DB_PASSWORD';
    CREATE DATABASE memory OWNER memory_user;

    CREATE USER audit_user WITH PASSWORD '$AUDIT_DB_PASSWORD';
    CREATE DATABASE audit OWNER audit_user;

    GRANT CONNECT ON DATABASE n8n TO n8n;
    GRANT CONNECT ON DATABASE memory TO memory_user;
    GRANT CONNECT ON DATABASE audit TO audit_user;
EOSQL
