-- Immutable audit log schema for SOX compliance
-- 7-year retention, partitioned by month

\connect audit;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Main audit events table (partitioned by month)
CREATE TABLE audit_events (
    id              UUID DEFAULT uuid_generate_v4(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Identity
    agent_id        VARCHAR(64) NOT NULL,
    client_id       VARCHAR(64) NOT NULL,
    user_id         VARCHAR(128),
    session_id      UUID,
    correlation_id  UUID,

    -- Action
    action_type     VARCHAR(64) NOT NULL,       -- query, read, create, update, delete, deploy, approve
    tool_name       VARCHAR(128),               -- MCP tool or RESTlet endpoint used
    tier            SMALLINT NOT NULL DEFAULT 1, -- 1=read-only, 2=low-risk, 3=medium, 4=high-value
    status          VARCHAR(32) NOT NULL,        -- requested, policy_denied, pending_approval, approved, rejected, executed, failed

    -- Context
    request_payload JSONB,                       -- What the agent requested
    response_payload JSONB,                      -- What was returned
    before_state    JSONB,                       -- Record state before modification (Tier 3+)
    after_state     JSONB,                       -- Record state after modification (Tier 3+)

    -- Policy
    policy_result   JSONB,                       -- OPA evaluation result
    approvers       JSONB,                       -- Array of {user_id, decision, timestamp}

    -- LLM Context
    model_id        VARCHAR(64),                 -- claude-3-haiku, claude-sonnet-4, etc.
    prompt_tokens   INTEGER,
    completion_tokens INTEGER,
    confidence_score NUMERIC(3,2),               -- Agent's self-assessed confidence (0.00-1.00)

    -- Metadata
    source_channel  VARCHAR(32),                 -- slack, email, webhook, ledgerlm, api
    duration_ms     INTEGER,
    error_message   TEXT,
    idempotency_key UUID,

    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create initial partitions (current month + next 3 months)
DO $$
DECLARE
    start_date DATE := DATE_TRUNC('month', CURRENT_DATE);
    partition_date DATE;
    partition_name TEXT;
BEGIN
    FOR i IN 0..3 LOOP
        partition_date := start_date + (i || ' months')::INTERVAL;
        partition_name := 'audit_events_' || TO_CHAR(partition_date, 'YYYY_MM');

        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I PARTITION OF audit_events
             FOR VALUES FROM (%L) TO (%L)',
            partition_name,
            partition_date,
            partition_date + INTERVAL '1 month'
        );
    END LOOP;
END $$;

-- Indexes for common query patterns
CREATE INDEX idx_audit_client_time ON audit_events (client_id, created_at DESC);
CREATE INDEX idx_audit_session ON audit_events (session_id, created_at);
CREATE INDEX idx_audit_correlation ON audit_events (correlation_id);
CREATE INDEX idx_audit_action_type ON audit_events (action_type, created_at DESC);
CREATE INDEX idx_audit_tier_status ON audit_events (tier, status, created_at DESC);
CREATE INDEX idx_audit_idempotency ON audit_events (idempotency_key) WHERE idempotency_key IS NOT NULL;

-- Prevent updates and deletes on audit records (immutability)
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit records are immutable. Updates and deletes are not permitted.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_immutable_update
    BEFORE UPDATE ON audit_events
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_modification();

CREATE TRIGGER audit_immutable_delete
    BEFORE DELETE ON audit_events
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_modification();

-- Evidence attachments table (for Tier 3/4 operations)
CREATE TABLE audit_evidence (
    id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    audit_event_id  UUID NOT NULL,
    audit_event_time TIMESTAMPTZ NOT NULL,  -- needed for partition routing
    evidence_type   VARCHAR(32) NOT NULL,    -- snapshot, diff, report, screenshot
    content         JSONB NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    FOREIGN KEY (audit_event_id, audit_event_time)
        REFERENCES audit_events (id, created_at)
);

CREATE INDEX idx_evidence_event ON audit_evidence (audit_event_id);

-- Function to auto-create future partitions (called by cron)
CREATE OR REPLACE FUNCTION create_audit_partition(target_date DATE)
RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    start_date := DATE_TRUNC('month', target_date);
    end_date := start_date + INTERVAL '1 month';
    partition_name := 'audit_events_' || TO_CHAR(start_date, 'YYYY_MM');

    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF audit_events
         FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        start_date,
        end_date
    );
END;
$$ LANGUAGE plpgsql;

-- Grant permissions to audit user
GRANT SELECT, INSERT ON audit_events TO audit_user;
GRANT SELECT, INSERT ON audit_evidence TO audit_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO audit_user;

COMMENT ON TABLE audit_events IS 'Immutable audit log for all agent actions. SOX-compliant with 7-year retention. Partitioned monthly.';
