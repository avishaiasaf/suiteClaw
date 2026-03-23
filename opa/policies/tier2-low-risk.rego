package tier2

import rego.v1

# Tier 2: Auto-approve with logging (low-risk writes)
# Draft emails, create ClickUp tasks, time entry logging, internal docs

default allow := false

allow if {
    input.tier == 2
    input.action_type in allowed_actions
    valid_client
}

# Also allow all Tier 1 actions
allow if {
    input.tier == 1
    data.tier1.allow with input as input
}

allowed_actions := {
    "draft_email",     # Draft (not send) emails
    "create_task",     # Create ClickUp tasks
    "log_time",        # Time entry logging
    "update_docs",     # Internal documentation updates
    "update_note",     # Add notes to records (non-financial)
    "memory_write",    # Store to agent memory
}

valid_client if {
    input.client_id == data.permissions.clients[_].client_id
}

# Tier 2 actions require single approval for certain sub-types
requires_approval if {
    input.action_type == "update_note"
    input.record_type in financial_record_types
}

financial_record_types := {
    "invoice",
    "vendorbill",
    "journalentry",
    "creditmemo",
    "payment",
    "deposit",
}
