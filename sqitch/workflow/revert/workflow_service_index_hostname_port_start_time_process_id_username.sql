-- Revert workflow_service_index_hostname_port_start_time_process_id_username

BEGIN;

DROP INDEX workflow.service_hostname_port_start_time_process_id_username_idx;

COMMIT;
