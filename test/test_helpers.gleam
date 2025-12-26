import config
import db_coordinator
import errors.{type AppError}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import global_value
import models/members
import models/members_db
import models/role
import pog
import wisp
import wisp/testing

pub fn setup_test_db() -> Result(db_coordinator.DbCoordName, AppError) {
  use <- global_value.create_with_unique_name("test_db")

  let config = config.load()
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
  telegram_id: Int,
) {
  let audit_cleanup_query =
    pog.query(
      "DELETE FROM admin_audit_log WHERE performed_by = $1 OR target_member = $1",
    )
    |> pog.parameter(pog.int(telegram_id))

  use _ <- result.try(db_coordinator.noresult_query(
    audit_cleanup_query,
    db_coord_name,
  ))

  let query_mem =
    pog.query("DELETE FROM members WHERE telegram_id = $1")
    |> pog.parameter(pog.int(telegram_id))

  db_coordinator.noresult_query(query_mem, db_coord_name)
}

pub fn create_test_member(
  db_coord_name: db_coordinator.DbCoordName,
  telegram_id: Int,
  first_name: String,
) -> Result(members.MemberRecord, String) {
  create_test_member_with_details(
    db_coord_name,
    telegram_id,
    first_name,
    option.None,
    role.Member,
  )
}

pub fn create_test_member_with_details(
  db_coord_name: db_coordinator.DbCoordName,
  telegram_id: Int,
  first_name: String,
  username: option.Option(String),
  _member_role: role.Role,
) -> Result(members.MemberRecord, String) {
  let auth_data =
    members_db.TelegramAuthData(
      telegram_id: telegram_id,
      first_name: first_name,
      username: username,
    )
  members_db.upsert_from_telegram(db_coord_name, auth_data)
  |> result.map_error(fn(_) { "Test member creation failed" })
}

pub fn set_session_cookie(
  request: wisp.Request,
  member: members.MemberRecord,
) -> wisp.Request {
  let session_value =
    int.to_string(member.telegram_id) <> ":" <> role.to_string(member.role)
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

pub fn update_form_data(emergency_contact: String) -> List(#(String, String)) {
  [#("emergency_contact", emergency_contact)]
}

pub fn admin_update_form_data(
  first_name: String,
  username: String,
  emergency_contact: String,
  role: String,
) -> List(#(String, String)) {
  [
    #("first_name", first_name),
    #("username", username),
    #("emergency_contact", emergency_contact),
    #("role", role),
  ]
}
