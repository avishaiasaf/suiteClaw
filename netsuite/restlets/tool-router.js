/**
 * @NApiVersion 2.1
 * @NScriptType Restlet
 * @NModuleScope SameAccount
 *
 * Agent Tool Router RESTlet
 *
 * Central entry point for AI agent operations in NetSuite.
 * Routes tool calls to the appropriate SuiteScript module.
 *
 * Supported tools:
 * - query_records: Execute SuiteQL queries (read-only)
 * - load_record: Load a single record by type and ID
 * - search_records: Execute a saved search by ID
 * - get_record_fields: Get field metadata for a record type
 */

define(['N/query', 'N/record', 'N/search', 'N/log', 'N/runtime'],
    (query, record, search, log, runtime) => {

        /**
         * Maximum governance units to consume before aborting.
         * RESTlet limit is 5,000. Reserve 500 for overhead.
         */
        const GOVERNANCE_LIMIT = 4500;

        /**
         * Maximum rows returned from SuiteQL queries.
         */
        const MAX_QUERY_ROWS = 5000;

        /**
         * Handle POST requests from the agent orchestrator.
         * @param {Object} requestBody - { tool: string, params: Object, correlation_id: string }
         * @returns {Object} - { success: boolean, data: any, error?: string, governance_used: number }
         */
        const post = (requestBody) => {
            const startUnits = runtime.getCurrentScript().getRemainingUsage();
            const { tool, params, correlation_id } = requestBody;

            log.audit({
                title: 'Agent Tool Request',
                details: JSON.stringify({ tool, params, correlation_id })
            });

            try {
                let result;

                switch (tool) {
                    case 'query_records':
                        result = executeQuery(params);
                        break;

                    case 'load_record':
                        result = loadRecord(params);
                        break;

                    case 'search_records':
                        result = executeSavedSearch(params);
                        break;

                    case 'get_record_fields':
                        result = getRecordFields(params);
                        break;

                    default:
                        return {
                            success: false,
                            error: `Unknown tool: ${tool}`,
                            correlation_id,
                            governance_used: startUnits - runtime.getCurrentScript().getRemainingUsage()
                        };
                }

                const governanceUsed = startUnits - runtime.getCurrentScript().getRemainingUsage();

                log.audit({
                    title: 'Agent Tool Response',
                    details: JSON.stringify({
                        tool,
                        correlation_id,
                        success: true,
                        row_count: Array.isArray(result) ? result.length : 1,
                        governance_used: governanceUsed
                    })
                });

                return {
                    success: true,
                    data: result,
                    correlation_id,
                    governance_used: governanceUsed
                };

            } catch (e) {
                log.error({
                    title: `Agent Tool Error: ${tool}`,
                    details: JSON.stringify({
                        message: e.message,
                        name: e.name,
                        correlation_id
                    })
                });

                return {
                    success: false,
                    error: e.message,
                    error_type: e.name,
                    correlation_id,
                    governance_used: startUnits - runtime.getCurrentScript().getRemainingUsage()
                };
            }
        };

        /**
         * Execute a SuiteQL query.
         * @param {Object} params - { sql: string, limit?: number }
         * @returns {Array} Query results as mapped objects
         */
        const executeQuery = (params) => {
            if (!params.sql) {
                throw new Error('Missing required parameter: sql');
            }

            // Basic SQL injection prevention — only allow SELECT statements
            const normalizedSql = params.sql.trim().toUpperCase();
            if (!normalizedSql.startsWith('SELECT') && !normalizedSql.startsWith('WITH')) {
                throw new Error('Only SELECT and WITH (CTE) statements are permitted');
            }

            const limit = Math.min(params.limit || MAX_QUERY_ROWS, MAX_QUERY_ROWS);

            const results = query.runSuiteQL({
                query: params.sql
            });

            const mappedResults = results.asMappedResults();
            return mappedResults.slice(0, limit);
        };

        /**
         * Load a single record by type and internal ID.
         * @param {Object} params - { type: string, id: number|string, fields?: string[] }
         * @returns {Object} Record data
         */
        const loadRecord = (params) => {
            if (!params.type || !params.id) {
                throw new Error('Missing required parameters: type, id');
            }

            const rec = record.load({
                type: params.type,
                id: params.id,
                isDynamic: false
            });

            // If specific fields requested, return only those
            if (params.fields && Array.isArray(params.fields)) {
                const result = { id: rec.id, type: rec.type };
                params.fields.forEach(field => {
                    result[field] = rec.getValue({ fieldId: field });
                    // Also get text value for list/record fields
                    try {
                        const text = rec.getText({ fieldId: field });
                        if (text) result[field + '_text'] = text;
                    } catch (_) { /* field doesn't support getText */ }
                });
                return result;
            }

            // Return full record as JSON
            return JSON.parse(JSON.stringify(rec));
        };

        /**
         * Execute a saved search by ID.
         * @param {Object} params - { search_id: string, limit?: number }
         * @returns {Array} Search results
         */
        const executeSavedSearch = (params) => {
            if (!params.search_id) {
                throw new Error('Missing required parameter: search_id');
            }

            const limit = Math.min(params.limit || 1000, 1000);
            const savedSearch = search.load({ id: params.search_id });
            const results = [];

            savedSearch.run().each((result) => {
                if (results.length >= limit) return false;
                if (runtime.getCurrentScript().getRemainingUsage() < 100) return false;

                const row = {};
                result.columns.forEach(col => {
                    const key = col.label || col.name;
                    row[key] = result.getText(col) || result.getValue(col);
                });
                results.push(row);
                return true;
            });

            return results;
        };

        /**
         * Get field metadata for a record type.
         * @param {Object} params - { type: string }
         * @returns {Object} Field definitions
         */
        const getRecordFields = (params) => {
            if (!params.type) {
                throw new Error('Missing required parameter: type');
            }

            // Load a blank record to inspect its fields
            const rec = record.create({ type: params.type, isDynamic: false });
            const fields = rec.getFields();

            return {
                type: params.type,
                field_count: fields.length,
                fields: fields.map(fieldId => {
                    const field = rec.getField({ fieldId });
                    return {
                        id: fieldId,
                        label: field.label,
                        type: field.type,
                        isMandatory: field.isMandatory,
                        isReadOnly: field.isReadonly
                    };
                })
            };
        };

        return { post };
    }
);
