-- Rollback for 002_create_admin_audit_table.sql

DROP TABLE IF EXISTS admin_audit_log;
DROP TYPE IF EXISTS admin_action_type;
