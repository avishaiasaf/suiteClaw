-- Audit Retention Policy
-- SOX requires 7-year retention for financial data
-- This function creates future partitions and can be called via cron

-- Create partitions for the next 6 months (run monthly via n8n scheduled workflow)
CREATE OR REPLACE FUNCTION maintain_audit_partitions()
RETURNS TEXT AS $$
DECLARE
    start_date DATE;
    partition_date DATE;
    partition_name TEXT;
    created_count INT := 0;
BEGIN
    -- Create partitions for the next 6 months
    FOR i IN 0..5 LOOP
        partition_date := DATE_TRUNC('month', CURRENT_DATE + (i || ' months')::INTERVAL);
        partition_name := 'audit_events_' || TO_CHAR(partition_date, 'YYYY_MM');

        -- Check if partition already exists
        IF NOT EXISTS (
            SELECT 1 FROM pg_tables
            WHERE tablename = partition_name
        ) THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF audit_events
                 FOR VALUES FROM (%L) TO (%L)',
                partition_name,
                partition_date,
                partition_date + INTERVAL '1 month'
            );
            created_count := created_count + 1;
        END IF;
    END LOOP;

    RETURN format('Created %s new partitions', created_count);
END;
$$ LANGUAGE plpgsql;

-- NOTE: Do NOT create a function to drop old partitions.
-- SOX requires 7-year retention. Partitions older than 7 years
-- must be archived to cold storage (S3 with Object Lock) before
-- being detached, and this should be a manual/approved process.
-- Never auto-delete audit data.
