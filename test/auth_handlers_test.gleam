import gleam/json
import gleam/list
import gleam/result
import gleam/string
import handlers
import models/membership_id
import test_helpers.{cleanup_test_member, create_test_member, setup_test_db}
import wisp
import wisp/testing

pub fn login_success_and_me_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "test_login@example.com"
  let test_password = "secret123"

  // Clean up and create test member
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(member) = create_test_member(conn, test_email, test_password)

  // Create login request
  let login_json =
    json.object([
      #("email_address", json.string(test_email)),
      #("password", json.string(test_password)),
    ])

  let login_req = testing.post_json("/auth/login", [], login_json)
  let login_response = handlers.login(login_req, conn)

  // Check login response
  let assert 200 = login_response.status
  let body = testing.string_body(login_response)
  let assert True = string.contains(body, "Login successful")

  // Extract session cookie from login response
  let session_cookie = case login_response.headers {
    [] -> panic as "No headers in login response"
    headers -> {
      headers
      |> list.find(fn(header) {
        let #(name, _value) = header
        name == "set-cookie"
      })
      |> result.map(fn(header) { header.1 })
      |> result.unwrap("no-cookie-found")
    }
  }
  let assert True = string.contains(session_cookie, "kadreg_session=")

  // Now test /auth/me with the actual session cookie
  let me_req = testing.get("/auth/me", [#("cookie", session_cookie)])
  let me_response = handlers.me(me_req, conn)

  // Check me response
  let assert 200 = me_response.status
  let me_body = testing.string_body(me_response)
  let member_id_str = membership_id.to_string(member.membership_id)
  let assert True = string.contains(me_body, member_id_str)

  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn login_invalid_credentials_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "test_login_fail@example.com"

  // Clean up and create test member
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(_member) =
    create_test_member(conn, test_email, "correct_password")

  // Try login with wrong password
  let login_json =
    json.object([
      #("email_address", json.string(test_email)),
      #("password", json.string("wrong_password")),
    ])

  let req = testing.post_json("/auth/login", [], login_json)
  let response = handlers.login(req, conn)

  // Check response
  let assert 401 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "error")

  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn login_invalid_email_test() {
  let assert Ok(conn) = setup_test_db()

  // Try login with nonexistent email
  let login_json =
    json.object([
      #("email_address", json.string("nonexistent@example.com")),
      #("password", json.string("anypassword")),
    ])

  let req = testing.post_json("/auth/login", [], login_json)
  let response = handlers.login(req, conn)

  // Check response
  let assert 401 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "error")
}

pub fn login_malformed_request_test() {
  let assert Ok(conn) = setup_test_db()

  // Send malformed JSON (missing password field)
  let login_json =
    json.object([#("email_address", json.string("test@example.com"))])

  let req = testing.post_json("/auth/login", [], login_json)
  let response = handlers.login(req, conn)

  // Check response - malformed request should return 400, not 401
  let assert 400 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "error")
}

pub fn logout_success_test() {
  let assert Ok(conn) = setup_test_db()

  let req = testing.post("/auth/logout", [], "")
  let response = handlers.logout(req, conn)

  // Check response
  let assert 200 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "Logout successful")

  // Check that cookie clearing header was set
  let has_clear_cookie = case response.headers {
    [] -> False
    headers -> {
      headers
      |> list.any(fn(header) {
        let #(name, value) = header
        name == "set-cookie" && string.contains(value, "kadreg_session=")
      })
    }
  }
  let assert True = has_clear_cookie
}

pub fn logout_no_session_test() {
  let assert Ok(conn) = setup_test_db()

  // Should work even without existing session
  let req = testing.post("/auth/logout", [], "")
  let response = handlers.logout(req, conn)

  let assert 200 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "Logout successful")
}

pub fn me_without_session_test() {
  let assert Ok(conn) = setup_test_db()

  let req = testing.get("/auth/me", [])
  let response = handlers.me(req, conn)

  // Check response
  let assert 401 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "No session found")
}

pub fn me_invalid_session_test() {
  let assert Ok(conn) = setup_test_db()

  let req =
    testing.get("/auth/me", [])
    |> testing.set_cookie("kadreg_session", "INVALID", wisp.Signed)

  let response = handlers.me(req, conn)

  // Check response
  let assert 401 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "Invalid session format")
}
