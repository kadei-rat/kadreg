import errors
import gleam/option
import models/members
import models/members_db
import models/pending_members_db
import test_helpers

pub fn pending_member_flow_test() {
  let assert Ok(db) = test_helpers.setup_test_db()
  let test_email = "pending@example.com"

  let _ = test_helpers.cleanup_test_member(db, test_email)

  let request =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Pending User",
      date_of_birth: "1990-01-01",
      handle: "pendinguser",
      postal_address: "123 Test St",
      phone_number: "555-0123",
      password: "verysecurepassword123",
      role: option.None,
    )

  let assert Ok(pending_member) = pending_members_db.create(db, request)
  let assert True = pending_member.email_address == test_email

  let assert Ok(member) =
    pending_members_db.confirm_and_convert_to_member(
      db,
      test_email,
      pending_member.email_confirm_token,
    )
  let assert True = member.email_address == test_email
  let assert True = member.legal_name == "Pending User"
  let assert True = member.handle == "pendinguser"

  let assert Ok(_) = members_db.get(db, member.membership_id)

  let assert Error(_) = pending_members_db.get(db, test_email)

  let _ = test_helpers.cleanup_test_member(db, test_email)
}

pub fn confirm_with_invalid_token_test() {
  let assert Ok(db) = test_helpers.setup_test_db()
  let test_email = "invalid@example.com"

  let _ = test_helpers.cleanup_test_member(db, test_email)

  let request =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Invalid Token User",
      date_of_birth: "1990-01-01",
      handle: "invaliduser",
      postal_address: "123 Test St",
      phone_number: "555-0123",
      password: "verysecurepassword123",
      role: option.None,
    )

  let assert Ok(_pending_member) = pending_members_db.create(db, request)

  let assert Error(_) =
    pending_members_db.confirm_and_convert_to_member(
      db,
      test_email,
      "wrong_token_12345",
    )

  let assert Ok(_) = pending_members_db.get(db, test_email)

  let _ = test_helpers.cleanup_test_member(db, test_email)
}

pub fn confirm_with_wrong_email_test() {
  let assert Ok(db) = test_helpers.setup_test_db()
  let test_email = "wrongemail@example.com"

  let _ = test_helpers.cleanup_test_member(db, test_email)

  let request =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Wrong Email User",
      date_of_birth: "1990-01-01",
      handle: "wrongemailuser",
      postal_address: "123 Test St",
      phone_number: "555-0123",
      password: "verysecurepassword123",
      role: option.None,
    )

  let assert Ok(pending_member) = pending_members_db.create(db, request)

  let assert Error(_) =
    pending_members_db.confirm_and_convert_to_member(
      db,
      "different@example.com",
      pending_member.email_confirm_token,
    )

  let _ = test_helpers.cleanup_test_member(db, test_email)
}

pub fn duplicate_pending_member_test() {
  let assert Ok(db) = test_helpers.setup_test_db()
  let test_email = "duplicate@example.com"

  let _ = test_helpers.cleanup_test_member(db, test_email)

  let request =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Duplicate User",
      date_of_birth: "1990-01-01",
      handle: "duplicateuser",
      postal_address: "123 Test St",
      phone_number: "555-0123",
      password: "verysecurepassword123",
      role: option.None,
    )

  let assert Ok(_) = pending_members_db.create(db, request)

  let assert Error(_) = pending_members_db.create(db, request)

  let _ = test_helpers.cleanup_test_member(db, test_email)
}

pub fn pending_member_with_existing_member_email_test() {
  let assert Ok(db) = test_helpers.setup_test_db()
  let test_email = "existing@example.com"

  let _ = test_helpers.cleanup_test_member(db, test_email)

  // First create a full member
  let assert Ok(_member) =
    test_helpers.create_test_member(db, test_email, "verysecurepassword123")

  // Try to create a pending member with the same email
  let request =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Pending User",
      date_of_birth: "1990-01-01",
      handle: "pendinguser",
      postal_address: "123 Test St",
      phone_number: "555-0123",
      password: "verysecurepassword123",
      role: option.None,
    )

  let assert Error(errors.ValidationError(
    public: "An account with this email address already exists",
    internal: _,
  )) = pending_members_db.create(db, request)

  let _ = test_helpers.cleanup_test_member(db, test_email)
}
