-- Create dedicated users and databases for each concern
-- Passwords are read from Docker secrets mounted as env vars during init

-- n8n database (workflow state, executions)
CREATE USER n8n WITH PASSWORD 'PLACEHOLDER_N8N_PASSWORD';
CREATE DATABASE n8n OWNER n8n;

-- Memory database (Mem0 vector store, agent memory)
CREATE USER memory_user WITH PASSWORD 'PLACEHOLDER_MEMORY_PASSWORD';
CREATE DATABASE memory OWNER memory_user;

-- Audit database (immutable audit logs, SOX compliance)
CREATE USER audit_user WITH PASSWORD 'PLACEHOLDER_AUDIT_PASSWORD';
CREATE DATABASE audit OWNER audit_user;

-- Grant connect permissions
GRANT CONNECT ON DATABASE n8n TO n8n;
GRANT CONNECT ON DATABASE memory TO memory_user;
GRANT CONNECT ON DATABASE audit TO audit_user;
