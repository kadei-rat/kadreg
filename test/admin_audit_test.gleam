// Integration tests for admin audit logging
import gleam/list
import gleam/option
import models/admin_audit
import models/admin_audit_db
import models/members
import models/members_db
import models/membership_id
import models/role
import test_helpers.{cleanup_test_member, setup_test_db}

pub fn admin_update_audit_log_test() {
  let assert Ok(db_coord) = setup_test_db()
  let admin_email = "admin_audit@example.com"
  let target_email = "target_audit@example.com"
  let update_email = "updated@example.com"

  // Clean up any existing test data
  let assert Ok(_) = cleanup_test_member(db_coord, admin_email)
  let assert Ok(_) = cleanup_test_member(db_coord, target_email)
  let assert Ok(_) = cleanup_test_member(db_coord, update_email)

  // Create admin user
  let admin_request =
    members.CreateMemberRequest(
      email_address: admin_email,
      legal_name: "Admin User",
      date_of_birth: "1985-01-01",
      handle: "adminaudituser",
      postal_address: "123 Admin St",
      phone_number: "555-0100",
      password: "adminpass123",
      role: option.Some(role.RegStaff),
    )

  let assert Ok(admin_member) = members_db.create(db_coord, admin_request)

  // Create target member to be edited
  let target_request =
    members.CreateMemberRequest(
      email_address: target_email,
      legal_name: "Target User",
      date_of_birth: "1990-05-15",
      handle: "targetaudituser",
      postal_address: "456 Target Ave",
      phone_number: "555-0200",
      password: "targetpass123",
      role: option.Some(role.Member),
    )

  let assert Ok(target_member) = members_db.create(db_coord, target_request)

  // Get initial audit log count
  let assert Ok(initial_audit_entries) = admin_audit_db.get_actions(db_coord)
  let initial_count = list.length(initial_audit_entries)

  // Perform admin update
  let update_request =
    members.AdminUpdateMemberRequest(
      email_address: update_email,
      legal_name: "Updated Name",
      date_of_birth: "1990-05-15",
      handle: "updatedhandle",
      postal_address: "789 Updated Blvd",
      phone_number: "555-0300",
      role: role.Staff,
    )

  let assert Ok(_updated_member) =
    members_db.admin_update(
      db_coord,
      admin_member.membership_id,
      target_member.membership_id,
      update_request,
    )

  // Verify audit log entry was created
  let assert Ok(audit_entries) = admin_audit_db.get_actions(db_coord)
  let new_count = list.length(audit_entries)
  let assert True = new_count == initial_count + 1

  // Get the most recent audit entry (first in the list since it's ordered DESC)
  let assert [latest_entry, ..] = audit_entries

  // Verify audit entry details
  let assert True =
    membership_id.to_string(latest_entry.performed_by)
    == membership_id.to_string(admin_member.membership_id)
  let assert True =
    membership_id.to_string(latest_entry.target_member)
    == membership_id.to_string(target_member.membership_id)
  let assert admin_audit.UpdateMember = latest_entry.action_type

  // Verify old values contain original data (JSON string)
  let assert True = {
    let contains_old_email = case target_email {
      "target_audit@example.com" -> True
      _ -> False
    }
    contains_old_email
  }

  // Verify new values contain updated data (JSON string)
  let assert True = {
    let contains_new_email = case update_request.email_address {
      "updated@example.com" -> True
      _ -> False
    }
    contains_new_email
  }

  // Clean up
  let assert Ok(_) = cleanup_test_member(db_coord, admin_email)
  let assert Ok(_) = cleanup_test_member(db_coord, target_email)
  let assert Ok(_) = cleanup_test_member(db_coord, update_email)
}
