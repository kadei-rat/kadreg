CREATE TYPE admin_action_type AS ENUM ('update_member', 'delete_member');

CREATE TABLE admin_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    performed_by INTEGER NOT NULL REFERENCES members(membership_num),
    action_type admin_action_type NOT NULL,
    target_member INTEGER NOT NULL REFERENCES members(membership_num),
    old_values JSONB,
    new_values JSONB,
    performed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for querying by admin who performed the action
CREATE INDEX idx_admin_audit_performed_by ON admin_audit_log (performed_by);

-- Index for querying by target member
CREATE INDEX idx_admin_audit_target_member ON admin_audit_log (target_member);

-- Index for querying by time
CREATE INDEX idx_admin_audit_performed_at ON admin_audit_log (performed_at DESC);
