package tier1

import rego.v1

# Tier 1: Auto-approve read-only operations
# SuiteQL queries, record reads, report generation, knowledge base searches

default allow := false

allow if {
    input.tier == 1
    input.action_type in allowed_actions
    valid_client
}

allowed_actions := {
    "query",          # SuiteQL queries
    "read",           # Record lookups
    "search",         # Saved search execution
    "report",         # Report generation
    "knowledge_read", # Knowledge base / memory reads
    "list",           # List records
}

# Client must be registered in permissions data
valid_client if {
    input.client_id == data.permissions.clients[_].client_id
}

# Deny reasons (for audit logging)
deny_reasons contains reason if {
    not input.action_type in allowed_actions
    reason := sprintf("Action '%s' is not permitted at Tier 1 (read-only)", [input.action_type])
}

deny_reasons contains reason if {
    not valid_client
    reason := sprintf("Client '%s' is not registered", [input.client_id])
}

deny_reasons contains reason if {
    input.tier != 1
    reason := sprintf("Tier %d operations require higher approval level", [input.tier])
}
