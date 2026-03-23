# SuiteScript Development Skill

## Code Generation Rules

When writing SuiteScript:

1. **Always SuiteScript 2.1** unless explicitly requested otherwise
2. **Always include JSDoc** with `@NApiVersion`, `@NScriptType`, `@NModuleScope`
3. **Always use define()** module pattern (not require())
4. **Always include error handling** with try/catch and `N/log`
5. **Always track governance** in loops with `runtime.getCurrentScript().getRemainingUsage()`
6. **Always validate parameters** before processing

## Script Type Templates

### User Event Script
```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType UserEventScript
 * @NModuleScope SameAccount
 * @description [Description]
 */
define(['N/record', 'N/log'], (record, log) => {
    const beforeSubmit = (context) => {
        if (context.type === context.UserEventType.CREATE ||
            context.type === context.UserEventType.EDIT) {
            try {
                // Logic here
            } catch (e) {
                log.error({ title: 'beforeSubmit Error', details: e.message });
                throw e;
            }
        }
    };
    return { beforeSubmit };
});
```

### Scheduled Script
```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType ScheduledScript
 * @NModuleScope SameAccount
 * @description [Description]
 */
define(['N/search', 'N/record', 'N/log', 'N/runtime'], (search, record, log, runtime) => {
    const execute = (context) => {
        try {
            const script = runtime.getCurrentScript();
            // Process with governance checks
            // if (script.getRemainingUsage() < 100) return;
        } catch (e) {
            log.error({ title: 'Scheduled Script Error', details: e.message });
        }
    };
    return { execute };
});
```

### Map/Reduce Script
```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType MapReduceScript
 * @NModuleScope SameAccount
 * @description [Description]
 */
define(['N/search', 'N/record', 'N/log'], (search, record, log) => {
    const getInputData = () => {
        // Return search, array, or object
    };

    const map = (context) => {
        try {
            const data = JSON.parse(context.value);
            // Process and emit
            context.write({ key: data.id, value: data });
        } catch (e) {
            log.error({ title: 'Map Error', details: e.message });
        }
    };

    const reduce = (context) => {
        try {
            // Aggregate by key
        } catch (e) {
            log.error({ title: 'Reduce Error', details: e.message });
        }
    };

    const summarize = (summary) => {
        summary.mapSummary.errors.iterator().each((key, error) => {
            log.error({ title: `Map Error: ${key}`, details: error });
            return true;
        });
    };

    return { getInputData, map, reduce, summarize };
});
```

## SDF Project Structure
```
src/
├── FileCabinet/SuiteScripts/SolutionLab/
│   ├── user-events/
│   ├── scheduled/
│   ├── map-reduce/
│   ├── suitelets/
│   ├── restlets/
│   └── client-scripts/
├── Objects/
│   ├── customrecord_*.xml
│   ├── customfield_*.xml
│   └── customscript_*.xml
├── manifest.xml
└── deploy.xml
```
