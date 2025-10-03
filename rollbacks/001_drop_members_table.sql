-- Rollback for 001_create_members_table.sql

-- Drop the trigger first
DROP TRIGGER IF EXISTS update_members_updated_at ON members;

-- Drop the trigger function
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop indexes (they'll be dropped with the table, but being explicit)
DROP INDEX IF EXISTS idx_members_email_active;
DROP INDEX IF EXISTS idx_members_role;

-- Drop the table (this will also drop any remaining indexes)
DROP TABLE IF EXISTS members;

-- Drop the enum type
DROP TYPE IF EXISTS member_role;
