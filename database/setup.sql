------------------------------
-- Members
------------------------------

CREATE TYPE member_role AS ENUM ('Member', 'Staff', 'RegStaff', 'Director', 'Sysadmin');

CREATE TABLE members (
    telegram_id BIGINT PRIMARY KEY,
    first_name TEXT NOT NULL,
    username TEXT,
    emergency_contact TEXT,
    role member_role NOT NULL DEFAULT 'Member',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_members_role ON members (role);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_members_updated_at
    BEFORE UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

------------------------------
-- Admin audit log
------------------------------

CREATE TYPE admin_action_type AS ENUM ('update_member', 'delete_member');

CREATE TABLE admin_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    performed_by BIGINT NOT NULL REFERENCES members(telegram_id),
    action_type admin_action_type NOT NULL,
    target_member BIGINT NOT NULL REFERENCES members(telegram_id),
    old_values JSONB,
    new_values JSONB,
    performed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_admin_audit_performed_by ON admin_audit_log (performed_by);
CREATE INDEX idx_admin_audit_target_member ON admin_audit_log (target_member);
CREATE INDEX idx_admin_audit_performed_at ON admin_audit_log (performed_at DESC);

------------------------------
-- Registrations
------------------------------

CREATE TYPE registration_tier AS ENUM ('standard', 'sponsor', 'subsidised', 'double_subsidised');
CREATE TYPE registration_status AS ENUM ('pending', 'successful', 'paid', 'cancelled');

CREATE TABLE registrations (
    member_id BIGINT NOT NULL REFERENCES members(telegram_id),
    convention_id TEXT NOT NULL,
    tier registration_tier NOT NULL,
    status registration_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (member_id, convention_id)
);

CREATE INDEX idx_registrations_convention ON registrations (convention_id);
CREATE INDEX idx_registrations_status ON registrations (convention_id, status);

CREATE TRIGGER update_registrations_updated_at
    BEFORE UPDATE ON registrations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
