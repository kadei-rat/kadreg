import config
import models/conventions
import models/membership_id
import models/registrations
import models/registrations_db
import models/role
import router
import test_helpers.{
  cleanup_test_member, create_test_member_with_details, setup_test_db,
}
import wisp/testing

fn cleanup_registration(db, member_id: Int, convention_id: String) {
  let sql =
    "DELETE FROM registrations WHERE member_id = $1 AND convention_id = $2"
  let query =
    pog.query(sql)
    |> pog.parameter(pog.int(member_id))
    |> pog.parameter(pog.text(convention_id))
  let _ = db_coordinator.noresult_query(query, db)
  Nil
}

import db_coordinator
import pog

pub fn create_registration_success_test() {
  let assert Ok(db) = setup_test_db()
  let email = "reg_create@example.com"
  let conf = config.load()
  let convention = conventions.current_convention

  let _ = cleanup_test_member(db, email)
  let assert Ok(member) =
    create_test_member_with_details(
      db,
      email,
      "pass",
      "Test",
      "test",
      role.Member,
    )

  cleanup_registration(db, member.membership_num, convention.id)

  let form_data = [
    #("convention_id", convention.id),
    #("tier", "standard"),
  ]
  let req =
    testing.post_form("/registrations", [], form_data)
    |> test_helpers.set_session_cookie(member)
  let response = router.handle_request(req, conf, db)

  let assert 303 = response.status

  // Verify registration was created
  let assert Ok(reg) =
    registrations_db.get(db, member.membership_num, convention.id)
  let assert registrations.Standard = reg.tier
  let assert registrations.Pending = reg.status

  cleanup_registration(db, member.membership_num, convention.id)
  let _ = cleanup_test_member(db, email)
}

pub fn create_registration_sponsor_tier_test() {
  let assert Ok(db) = setup_test_db()
  let email = "reg_sponsor@example.com"
  let conf = config.load()
  let convention = conventions.current_convention

  let _ = cleanup_test_member(db, email)
  let assert Ok(member) =
    create_test_member_with_details(
      db,
      email,
      "pass",
      "Test",
      "test",
      role.Member,
    )

  cleanup_registration(db, member.membership_num, convention.id)

  let form_data = [
    #("convention_id", convention.id),
    #("tier", "sponsor"),
  ]
  let req =
    testing.post_form("/registrations", [], form_data)
    |> test_helpers.set_session_cookie(member)
  let response = router.handle_request(req, conf, db)

  let assert 303 = response.status

  let assert Ok(reg) =
    registrations_db.get(db, member.membership_num, convention.id)
  let assert registrations.Sponsor = reg.tier

  cleanup_registration(db, member.membership_num, convention.id)
  let _ = cleanup_test_member(db, email)
}

pub fn update_registration_tier_test() {
  let assert Ok(db) = setup_test_db()
  let email = "reg_update@example.com"
  let conf = config.load()
  let convention = conventions.current_convention

  let _ = cleanup_test_member(db, email)
  let assert Ok(member) =
    create_test_member_with_details(
      db,
      email,
      "pass",
      "Test",
      "test",
      role.Member,
    )

  cleanup_registration(db, member.membership_num, convention.id)
  let assert Ok(_) =
    registrations_db.create(
      db,
      member.membership_num,
      convention.id,
      registrations.Standard,
    )

  let form_data = [#("tier", "subsidised")]
  let req =
    testing.post_form("/registrations/" <> convention.id, [], form_data)
    |> test_helpers.set_session_cookie(member)
  let response = router.handle_request(req, conf, db)

  let assert 303 = response.status

  let assert Ok(reg) =
    registrations_db.get(db, member.membership_num, convention.id)
  let assert registrations.Subsidised = reg.tier

  cleanup_registration(db, member.membership_num, convention.id)
  let _ = cleanup_test_member(db, email)
}

pub fn cancel_registration_test() {
  let assert Ok(db) = setup_test_db()
  let email = "reg_cancel@example.com"
  let conf = config.load()
  let convention = conventions.current_convention

  let _ = cleanup_test_member(db, email)
  let assert Ok(member) =
    create_test_member_with_details(
      db,
      email,
      "pass",
      "Test",
      "test",
      role.Member,
    )

  cleanup_registration(db, member.membership_num, convention.id)
  let assert Ok(_) =
    registrations_db.create(
      db,
      member.membership_num,
      convention.id,
      registrations.Standard,
    )

  let req =
    testing.post("/registrations/" <> convention.id <> "/cancel", [], "")
    |> test_helpers.set_session_cookie(member)
  let response = router.handle_request(req, conf, db)

  let assert 303 = response.status

  let assert Ok(reg) =
    registrations_db.get(db, member.membership_num, convention.id)
  let assert registrations.Cancelled = reg.status

  cleanup_registration(db, member.membership_num, convention.id)
  let _ = cleanup_test_member(db, email)
}

pub fn cannot_modify_paid_registration_test() {
  let assert Ok(db) = setup_test_db()
  let email = "reg_paid@example.com"
  let conf = config.load()
  let convention = conventions.current_convention

  let _ = cleanup_test_member(db, email)
  let assert Ok(member) =
    create_test_member_with_details(
      db,
      email,
      "pass",
      "Test",
      "test",
      role.Member,
    )

  cleanup_registration(db, member.membership_num, convention.id)
  let assert Ok(_) =
    registrations_db.create(
      db,
      member.membership_num,
      convention.id,
      registrations.Standard,
    )
  let assert Ok(_) =
    registrations_db.update_status(
      db,
      member.membership_num,
      convention.id,
      registrations.Paid,
    )

  // Try to cancel - should fail
  let req =
    testing.post("/registrations/" <> convention.id <> "/cancel", [], "")
    |> test_helpers.set_session_cookie(member)
  let response = router.handle_request(req, conf, db)

  let assert 303 = response.status
  // Should redirect with error
  let location = test_helpers.get_location_header(response)
  let assert True = location != "/register"

  // Verify status unchanged
  let assert Ok(reg) =
    registrations_db.get(db, member.membership_num, convention.id)
  let assert registrations.Paid = reg.status

  cleanup_registration(db, member.membership_num, convention.id)
  let _ = cleanup_test_member(db, email)
}

pub fn admin_update_registration_test() {
  let assert Ok(db) = setup_test_db()
  let admin_email = "reg_admin@example.com"
  let member_email = "reg_member@example.com"
  let conf = config.load()
  let convention = conventions.current_convention

  let _ = cleanup_test_member(db, admin_email)
  let _ = cleanup_test_member(db, member_email)

  let assert Ok(admin) =
    create_test_member_with_details(
      db,
      admin_email,
      "pass",
      "Admin",
      "admin",
      role.RegStaff,
    )
  let assert Ok(member) =
    create_test_member_with_details(
      db,
      member_email,
      "pass",
      "Member",
      "member",
      role.Member,
    )

  cleanup_registration(db, member.membership_num, convention.id)
  let assert Ok(_) =
    registrations_db.create(
      db,
      member.membership_num,
      convention.id,
      registrations.Standard,
    )

  let member_id_str = membership_id.to_string(member.membership_id)
  let form_data = [
    #("tier", "double_subsidised"),
    #("status", "successful"),
  ]
  let req =
    testing.post_form("/admin/registrations/" <> member_id_str, [], form_data)
    |> test_helpers.set_session_cookie(admin)
  let response = router.handle_request(req, conf, db)

  let assert 303 = response.status

  let assert Ok(reg) =
    registrations_db.get(db, member.membership_num, convention.id)
  let assert registrations.DoubleSubsidised = reg.tier
  let assert registrations.Successful = reg.status

  cleanup_registration(db, member.membership_num, convention.id)
  let _ = cleanup_test_member(db, admin_email)
  let _ = cleanup_test_member(db, member_email)
}

pub fn registration_unauthorized_test() {
  let assert Ok(db) = setup_test_db()
  let conf = config.load()
  let convention = conventions.current_convention

  let form_data = [
    #("convention_id", convention.id),
    #("tier", "standard"),
  ]
  let req = testing.post_form("/registrations", [], form_data)
  let response = router.handle_request(req, conf, db)

  let assert 401 = response.status
}
