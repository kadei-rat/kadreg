CREATE TABLE pending_members (
    email_address TEXT PRIMARY KEY,
    legal_name TEXT NOT NULL,
    date_of_birth TEXT NOT NULL,
    handle TEXT NOT NULL,
    postal_address TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    email_confirm_token TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index by created_at to allow eventual deletion of never-confirmed members from before a certain date
CREATE INDEX idx_pending_members_created_at ON pending_members (created_at);

-- Prevent pending_members from having an email that exists in members
CREATE OR REPLACE FUNCTION check_pending_member_email()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM members
    WHERE email_address = NEW.email_address
    AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'An account with this email address already exists'
      USING ERRCODE = '23505'; -- unique_violation error code
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_duplicate_email_in_pending_members
  BEFORE INSERT ON pending_members
  FOR EACH ROW
  EXECUTE FUNCTION check_pending_member_email();
