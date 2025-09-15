import config
import gleam/string
import models/membership_id
import router
import test_helpers
import wisp
import wisp/testing

pub fn protected_route_without_session_test() {
  let conf = config.load()
  let assert Ok(conn) = test_helpers.setup_test_db()

  // Test GET /admin/members without session
  let req = testing.get("/admin/members", [])
  let response = router.handle_request(req, conf, conn)

  // Should return 401 Unauthorized
  let assert 401 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "Authentication required")
}

pub fn protected_route_invalid_session_test() {
  let conf = config.load()
  let assert Ok(conn) = test_helpers.setup_test_db()

  // Test GET /admin/members with invalid session cookie
  let req =
    testing.get("/admin/members", [])
    |> testing.set_cookie("kadreg_session", "INVALID_ID", wisp.Signed)

  let response = router.handle_request(req, conf, conn)

  // Should return 401 Unauthorized
  let assert 401 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "Authentication required")
}

pub fn protected_get_member_route_test() {
  let conf = config.load()
  let assert Ok(conn) = test_helpers.setup_test_db()
  let test_email = "test_get_member@example.com"

  // Clean up and create test member
  let _ = test_helpers.cleanup_test_member(conn, test_email)
  let assert Ok(member) =
    test_helpers.create_test_member(conn, test_email, "password123")

  // Test GET /admin/members/{id} with valid session
  let member_id_str = membership_id.to_string(member.membership_id)
  let req =
    testing.get("/admin/members/" <> member_id_str, [])
    |> test_helpers.set_session_cookie(member)

  let response = router.handle_request(req, conf, conn)

  // Should succeed and return member data
  let assert 200 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, member_id_str)

  // Cleanup
  let _ = test_helpers.cleanup_test_member(conn, test_email)
}
