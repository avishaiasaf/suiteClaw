# SOX Compliance Rules

## Mandatory Controls

1. **Separation of Duties**: Never combine vendor creation with payment approval
2. **Audit Trail**: Every action generates an immutable audit log entry
3. **Evidence Collection**: Tier 3+ operations require before/after state snapshots
4. **Approval Gates**: Financial modifications require human approval
5. **Deny on Timeout**: Unapproved actions default to DENY, never auto-approve
6. **Retention**: Audit logs retained for 7 years minimum
7. **Idempotency**: All write operations use idempotency keys to prevent duplicates

## What Requires Approval
- Any record creation or modification involving financial amounts
- Journal entries of any value
- Vendor bill creation or modification
- Revenue recognition changes
- Period close operations
- Intercompany transactions
- Production deployments
- Bulk operations (any operation affecting >10 records)

## What Never Requires Approval
- Read-only queries (SuiteQL, saved searches, reports)
- Knowledge base lookups
- Draft preparation (emails, proposals — not sending)
- Internal documentation updates
- Memory storage operations
