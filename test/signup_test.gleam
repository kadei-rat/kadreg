import config
import gleam/string
import router
import test_helpers.{cleanup_test_member, get_location_header, setup_test_db}
import wisp/testing

pub fn signup_success_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "newsignup@example.com"
  let conf = config.load()

  // Clean up any existing test member
  let _ = cleanup_test_member(conn, test_email)

  // Create signup form data
  let form_data = [
    #("email_address", test_email),
    #("legal_name", "New Signup User"),
    #("date_of_birth", "1990-05-15"),
    #("handle", "newsignup"),
    #("postal_address", "456 Signup St"),
    #("phone_number", "555-1234"),
    #("password", "strongpassword123"),
  ]

  // Submit signup form
  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, conn)

  // Should redirect to success page
  let assert 303 = response.status
  let location_header = get_location_header(response)
  let assert True = string.contains(location_header, "/?success=")
  let assert True =
    string.contains(location_header, "Account%20created%20successfully")

  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn signup_validation_failure_test() {
  let assert Ok(conn) = setup_test_db()
  let conf = config.load()

  // Create signup form data with password that's too short
  let form_data = [
    #("email_address", "shortpass@example.com"),
    #("legal_name", "Short Pass User"),
    #("date_of_birth", "1990-05-15"),
    #("handle", "shortpass"),
    #("postal_address", "456 Short St"),
    #("phone_number", "555-5678"),
    #("password", "short"),
    // This should fail validation (< 12 chars)
  ]

  // Submit signup form
  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, conn)

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
  let assert Ok(conn) = setup_test_db()
  let conf = config.load()

  // Create signup form data missing required field (legal_name)
  let form_data = [
    #("email_address", "missingfield@example.com"),
    // Missing legal_name
    #("date_of_birth", "1990-05-15"),
    #("handle", "missingfield"),
    #("postal_address", "456 Missing St"),
    #("phone_number", "555-9999"),
    #("password", "strongpassword123"),
  ]

  // Submit signup form
  let req = testing.post_form("/members", [], form_data)
  let response = router.handle_request(req, conf, conn)

  // Should redirect to signup page with error
  let assert 303 = response.status
  let location_header = get_location_header(response)
  let assert True = string.contains(location_header, "/signup?error=")
  let assert True = string.contains(location_header, "Missing%20field")
}
