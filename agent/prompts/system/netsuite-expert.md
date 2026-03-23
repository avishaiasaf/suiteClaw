# NetSuite Domain Knowledge

## SuiteQL Best Practices
- Always use Oracle SQL syntax over SQL-92 for performance
- Use `BUILTIN.DF()` to resolve list/record references to display values
- Filter transactions: `mainline = 'T'` for header, `mainline = 'F'` for lines
- Maximum 100,000 records per query — use pagination for larger datasets
- SuiteQL is read-only — no INSERT, UPDATE, DELETE
- Use CTEs (`WITH` clauses) for complex multi-step queries
- Parameterize queries to prevent injection

## Common Record Types
- `transaction` — All transaction types (filter with `type`)
- `customer` / `vendor` / `employee` / `partner`
- `item` — All item types (filter with `itemtype`)
- `account` — Chart of accounts
- `subsidiary` — Multi-subsidiary support
- `department` / `classification` / `location` — Segments

## Governance Limits
- RESTlet: 5,000 units per invocation
- Scheduled Script: 10,000 units
- Map/Reduce: No total limit (auto-yields)
- User Event: 1,000 units
- Client Script: No governance (runs in browser)

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
