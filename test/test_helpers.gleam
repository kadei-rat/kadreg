import config
import database
import gleam/list
import gleam/option
import gleam/result
import models/members
import models/membership_id
import models/role
import pog
import wisp
import wisp/testing

pub fn setup_test_db() -> Result(pog.Connection, String) {
  let config = config.load()
  // Use test database name if running in test mode
  let test_config = config.Config(..config, db_name_suffix: "_test")
  database.connect(test_config)
}

pub fn cleanup_test_member(
  conn: pog.Connection,
  email: String,
) -> Result(Nil, String) {
  let sql = "DELETE FROM members WHERE email_address = $1"

  use _ <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(email))
    |> pog.execute(conn)
    |> result.map_error(fn(_) { "Cleanup failed" }),
  )

  Ok(Nil)
}

pub fn create_test_member(
  conn: pog.Connection,
  email: String,
  password: String,
) -> Result(members.MemberRecord, String) {
  create_test_member_with_details(
    conn,
    email,
    password,
    "Test User",
    "testuser",
    role.Member,
  )
}

pub fn create_test_member_with_details(
  conn: pog.Connection,
  email: String,
  password: String,
  legal_name: String,
  handle: String,
  member_role: role.Role,
) -> Result(members.MemberRecord, String) {
  let request =
    members.CreateMemberRequest(
      email_address: email,
      legal_name: legal_name,
      date_of_birth: "1990-01-01",
      handle: handle,
      postal_address: "123 Test St",
      phone_number: "555-0123",
      password: password,
      role: option.Some(member_role),
    )
  members.create(conn, request)
  |> result.map_error(fn(_) { "Test member creation failed" })
}

pub fn set_session_cookie(
  request: wisp.Request,
  member: members.MemberRecord,
) -> wisp.Request {
  let session_value =
    membership_id.to_string(member.membership_id)
    <> ":"
    <> role.to_string(member.role)
  testing.set_cookie(request, "kadreg_session", session_value, wisp.Signed)
}

pub fn get_location_header(response: wisp.Response) -> String {
  case response.headers {
    [] -> "no-location-header"
    headers -> {
      headers
      |> list.find(fn(header) {
        let #(name, _value) = header
        name == "location"
      })
      |> result.map(fn(header) { header.1 })
      |> result.unwrap("no-location-header")
    }
  }
}

pub fn member_form_data(
  email: String,
  name: String,
  handle: String,
) -> List(#(String, String)) {
  [
    #("email_address", email),
    #("legal_name", name),
    #("date_of_birth", "1990-01-01"),
    #("handle", handle),
    #("postal_address", "123 Test St"),
    #("phone_number", "555-0123"),
    #("password", "testpass123"),
  ]
}

pub fn update_form_data(
  email: String,
  name: String,
  handle: String,
) -> List(#(String, String)) {
  [
    #("email_address", email),
    #("legal_name", name),
    #("date_of_birth", "1990-01-01"),
    #("handle", handle),
    #("postal_address", "456 Updated St"),
    #("phone_number", "555-9999"),
  ]
}

pub fn admin_update_form_data(
  email: String,
  name: String,
  handle: String,
  role: String,
) -> List(#(String, String)) {
  [
    #("email_address", email),
    #("legal_name", name),
    #("date_of_birth", "1990-01-01"),
    #("handle", handle),
    #("postal_address", "789 Admin St"),
    #("phone_number", "555-8888"),
    #("role", role),
  ]
}
