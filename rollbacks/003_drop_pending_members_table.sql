-- Rollback for 003_create_pending_members_table.sql

DROP TRIGGER IF EXISTS prevent_duplicate_email_in_pending_members ON pending_members;
DROP FUNCTION IF EXISTS check_pending_member_email();
DROP INDEX IF EXISTS idx_pending_members_created_at;
DROP TABLE IF EXISTS pending_members;
