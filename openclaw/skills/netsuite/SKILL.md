# NetSuite Operations Skill

## Available Tools (via n8n MCP)

These tools are available through the n8n MCP connection. Use them for live NetSuite data operations.

### SuiteQL Query
- **Tool**: `netsuite_suiteql` (via n8n)
- **Purpose**: Execute read-only SQL queries against NetSuite
- **Syntax**: Oracle SQL (not SQL-92)
- **Max results**: 100,000 rows per query
- **Key rules**:
  - Always use `BUILTIN.DF()` for list/record field display values
  - Filter transactions: `mainline = 'T'` for header, `'F'` for lines
  - Use CTEs (`WITH` clauses) for complex multi-step queries
  - SuiteQL is READ-ONLY — no INSERT, UPDATE, DELETE

### Record Operations
- **Read**: `netsuite_get_record` — load a record by type and internal ID
- **Create**: `netsuite_create_record` — create a new record (Tier 3+, requires approval)
- **Update**: `netsuite_update_record` — modify record fields (Tier 3+, requires approval)
- **Search**: `netsuite_saved_search` — execute a saved search by ID

## Common SuiteQL Patterns

### Open Invoices
```sql
SELECT t.tranid, t.trandate, BUILTIN.DF(t.entity) AS customer,
       t.foreigntotal, t.foreignamountremaining
FROM transaction t
WHERE t.type = 'CustInvc' AND t.mainline = 'T'
  AND t.foreignamountremaining > 0
ORDER BY t.trandate DESC
```

### Vendor Bill Aging
```sql
SELECT t.tranid, t.trandate, BUILTIN.DF(t.entity) AS vendor,
       t.foreigntotal, t.foreignamountremaining,
       TRUNC(SYSDATE) - t.duedate AS days_overdue
FROM transaction t
WHERE t.type = 'VendBill' AND t.mainline = 'T'
  AND t.foreignamountremaining > 0
ORDER BY days_overdue DESC
```

### Customer List
```sql
SELECT c.id, c.companyname, c.email, BUILTIN.DF(c.subsidiary) AS subsidiary,
       c.balance, c.overduebalance
FROM customer c
WHERE c.isinactive = 'F'
ORDER BY c.companyname
```

### Item Search
```sql
SELECT i.id, i.itemid, i.displayname, BUILTIN.DF(i.itemtype) AS type,
       i.baseprice, i.quantityavailable
FROM item i
WHERE i.isinactive = 'F'
ORDER BY i.itemid
```

## Governance Limits Reference
| Script Type | Governance Units |
|------------|-----------------|
| RESTlet | 5,000 |
| Scheduled Script | 10,000 |
| Map/Reduce | No total limit (auto-yields) |
| User Event | 1,000 |
| Suitelet | 10,000 |
| Client Script | No governance (browser) |
