import config
import db_coordinator
import errors.{type AppError}
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import global_value
import models/members
import models/members_db
import models/membership_id
import models/role
import pog
import wisp
import wisp/testing

pub fn setup_test_db() -> Result(db_coordinator.DbCoordName, AppError) {
  // global_value memoises the db connection. static key, assumes that a given
  // process will only ever use a single db config.
  use <- global_value.create_with_unique_name("test_db")

  let config = config.load()
  // Use test database name if running in test mode
  let test_config = config.Config(..config, db_name_suffix: "_test")

  let db_coord_name = process.new_name(prefix: "test_db_coord")
  case db_coordinator.start(test_config, db_coord_name) {
    Ok(_) -> Ok(db_coord_name)
    Error(err) ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Test database coordinator failed to start: " <> string.inspect(err),
      ))
  }
}

pub fn cleanup_test_member(
  db_coord_name: db_coordinator.DbCoordName,
  email: String,
) -> Result(Nil, String) {
  let query =
    pog.query("DELETE FROM members WHERE email_address = $1")
    |> pog.parameter(pog.text(email))

  case db_coordinator.noresult_query(query, db_coord_name) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("Cleanup failed")
  }
}

pub fn create_test_member(
  db_coord_name: db_coordinator.DbCoordName,
  email: String,
  password: String,
) -> Result(members.MemberRecord, String) {
  create_test_member_with_details(
    db_coord_name,
    email,
    password,
    "Test User",
    "testuser",
    role.Member,
  )
}

pub fn create_test_member_with_details(
  db_coord_name: db_coordinator.DbCoordName,
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
  members_db.create(db_coord_name, request)
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
