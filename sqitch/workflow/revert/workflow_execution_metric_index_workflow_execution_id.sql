-- Revert workflow_execution_metric_index_workflow_execution_id

BEGIN;

DROP INDEX workflow.execution_metric_workflow_execution_id_idx;

COMMIT;
