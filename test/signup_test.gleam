import config
import gleam/string
import models/members_db
import models/pending_members_db
import router
import test_helpers.{cleanup_test_member, get_location_header, setup_test_db}
import wisp/testing

pub fn signup_success_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "newsignup@example.com"
  let conf = config.load()

  // Clean up any existing test data
  let _ = cleanup_test_member(db_coord, test_email)

  // Create signup form data
  let form_data = [
    #("email_address", test_email),
    #("handle", "newsignup"),
    #("password", "strongpassword123"),
  ]

  // Submit signup form
  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, db_coord)

  // Should redirect to success page with email confirmation message
  let assert 303 = response.status
  let location_header = get_location_header(response)
  let assert True = string.contains(location_header, "/?success=")
  let assert True = string.contains(location_header, "Account%20created")
  let assert True = string.contains(location_header, "email")

  // Verify pending member was created (not a full member)
  let assert Ok(_pending_member) = pending_members_db.get(db_coord, test_email)

  // Verify NO full member was created yet
  let assert Error(_) = members_db.get_by_email(db_coord, test_email)

  // Cleanup
  let _ = cleanup_test_member(db_coord, test_email)
}

pub fn signup_validation_failure_test() {
  let assert Ok(db_coord) = setup_test_db()
  let conf = config.load()

  // Create signup form data with password that's too short
  let form_data = [
    #("email_address", "shortpass@example.com"),
    #("handle", "shortpass"),
    #("password", "short"),
    // This should fail validation (< 12 chars)
  ]

  // Submit signup form
  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, db_coord)

  // Should redirect to signup page with error
  let assert 303 = response.status
  let location_header = get_location_header(response)
  let assert True = string.contains(location_header, "/signup?error=")
  let assert True =
    string.contains(
      location_header,
      "Password%20must%20be%20at%20least%2012%20characters",
    )
}

pub fn signup_missing_field_test() {
  let assert Ok(db_coord) = setup_test_db()
  let conf = config.load()

  // Create signup form data missing required field (email)
  let form_data = [
    // Missing email address
    #("email_address", ""),
    #("handle", "missingfield"),
    #("password", "strongpassword123456"),
  ]

  // Submit signup form
  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, db_coord)

  // Should redirect to signup page with error
  let assert 303 = response.status
  let location_header = get_location_header(response)
  let assert True = string.contains(location_header, "/signup?error=")
  let assert True = string.contains(location_header, "email")
}

pub fn signup_with_existing_member_email_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "alreadyexists@example.com"
  let conf = config.load()

  // Clean up any existing test data
  let _ = cleanup_test_member(db_coord, test_email)

  // First create a full member with this email
  let assert Ok(_member) =
    test_helpers.create_test_member(db_coord, test_email, "password123456")

  // Try to sign up with the same email
  let form_data = [
    #("email_address", test_email),
    #("handle", "newsignup"),
    #("password", "strongpassword123"),
  ]

  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, db_coord)

  // Should redirect to signup page with error
  let assert 303 = response.status
  let location_header = get_location_header(response)
  let assert True = string.contains(location_header, "/signup?error=")
  let assert True =
    string.contains(
      location_header,
      "An%20account%20with%20this%20email%20address%20already%20exists",
    )

  // Verify NO pending member was created
  let assert Error(_) = pending_members_db.get(db_coord, test_email)

  let _ = cleanup_test_member(db_coord, test_email)
}
