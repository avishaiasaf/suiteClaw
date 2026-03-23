# Intent Classification Prompt (Haiku)

Classify the user's message into exactly one intent category. Respond with JSON only.

## Categories

| Intent | Description | Examples |
|--------|-------------|----------|
| `suiteql_query` | User wants to query NetSuite data | "Show me open invoices", "How many POs last month?" |
| `record_lookup` | User wants to view a specific record | "Show me vendor 12345", "What's on SO-100234?" |
| `saved_search` | User wants to run or view a saved search | "Run the aging report search", "Show saved search 456" |
| `report` | User wants a report or analysis | "Generate AR aging", "Revenue by subsidiary" |
| `suitescript_gen` | User wants SuiteScript code written | "Create a user event script", "Write a scheduled script" |
| `record_update` | User wants to modify a record | "Update the phone number on contact 789", "Change PO status" |
| `record_create` | User wants to create a new record | "Create a journal entry", "Add a new vendor" |
| `task_management` | User wants to manage ClickUp tasks | "Create a task for...", "What's the status of..." |
| `email_draft` | User wants to compose an email | "Draft an email to the client about..." |
| `knowledge` | User asks about NetSuite concepts/best practices | "What's the difference between...", "How does revenue recognition work?" |
| `deploy` | User wants to deploy code to NetSuite | "Deploy the script to sandbox", "Push to production" |
| `browser_action` | User wants UI-level NetSuite interaction | "Configure the custom segment", "Set up the workflow in UI" |
| `unknown` | Cannot determine intent | Ambiguous or off-topic messages |

## Response Format

```json
{
  "intent": "<category>",
  "confidence": <0.0-1.0>,
  "tier": <1-4>,
  "entities": {
    "record_type": "<if applicable>",
    "record_id": "<if applicable>",
    "client_id": "<if provided>"
  },
  "reasoning": "<one sentence explanation>"
}
```

## Tier Assignment Rules
- Tier 1: suiteql_query, record_lookup, saved_search, report, knowledge
- Tier 2: email_draft, task_management
- Tier 3: record_update, record_create (non-financial or under threshold)
- Tier 4: record_create (financial, over threshold), deploy (production), browser_action (permissions)

## User Message
{{message}}
