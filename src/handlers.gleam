import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/result
import models/members
import models/membership_id
import pog
import session
import utils
import wisp.{type Request, type Response}

// Handlers

// POST /members (Create a new member)
pub fn create_member_handler(req: Request, db: pog.Connection) -> Response {
  use body <- wisp.require_json(req)

  members.decode_create_member_request(body)
  |> result.try(members.create(db, _))
  |> result.map(members.to_json)
  |> result.map(json.to_string_tree)
  |> result.map(wisp.json_response(_, 201))
  |> result.map_error(fn(err) { json_error_response(err, 400) })
  |> result.unwrap_both
}

// GET /members/<membership_id> (Get a specific member)
pub fn get_member_handler(
  _req: Request,
  db: pog.Connection,
  membership_id_str: String,
) -> Response {
  membership_id.parse(membership_id_str)
  |> result.try(members.get(db, _))
  |> result.map(members.to_json)
  |> result.map(json.to_string_tree)
  |> result.map(wisp.json_response(_, 200))
  |> result.map_error(fn(err) { json_error_response(err, 400) })
  |> result.unwrap_both
}

// GET /members (List all members)
pub fn list_members_handler(_req: Request, db: pog.Connection) -> Response {
  members.list(db)
  |> result.map(json.array(_, members.to_json))
  |> result.map(json.to_string_tree)
  |> result.map(wisp.json_response(_, 200))
  |> result.map_error(fn(err) { json_error_response(err, 400) })
  |> result.unwrap_both
}

// Update a member - PATCH /members
pub fn update_member_handler(req: Request, _db: pog.Connection) -> Response {
  use _body <- wisp.require_json(req)

  let error_json =
    json.object([#("error", json.string("Update not yet implemented"))])
  wisp.json_response(json.to_string_tree(error_json), 501)
}

// POST /members/<membership_id>/delete (Delete a member)
pub fn delete_member_handler(
  _req: Request,
  db: pog.Connection,
  membership_id_str: String,
) -> Response {
  // For now, default to not purging PII. (in future need to be optional, in req body or param)
  let purge_pii = False

  membership_id.parse(membership_id_str)
  |> result.try(members.delete(db, _, purge_pii))
  |> result.map(fn(_) { wisp.ok() })
  |> result.map_error(fn(err) { json_error_response(err, 400) })
  |> result.unwrap_both
}

// POST /auth/login (Create a session)
pub fn login_handler(req: Request, db: pog.Connection) -> Response {
  use body <- wisp.require_json(req)

  decode_login_request(body)
  |> result.try(fn(data) {
    members.authenticate(db, data.email_address, data.password)
  })
  |> result.map(fn(member) {
    session.create_session(wisp.ok(), req, member.membership_id)
  })
  |> result.map_error(fn(err) { json_error_response(err, 401) })
  |> result.unwrap_both
}

// POST /auth/logout (Destroy session)
pub fn logout_handler(req: Request, _db: pog.Connection) -> Response {
  let success_json =
    json.object([#("message", json.string("Logout successful"))])
  wisp.json_response(json.to_string_tree(success_json), 200)
  |> session.destroy_session(req)
}

// GET /auth/me (Get current session info)
pub fn me_handler(req: Request, _db: pog.Connection) -> Response {
  case session.get_session(req) {
    Ok(membership_id) -> {
      let user_json = json.object([
        #("membership_id", json.string(membership_id.to_string(membership_id)))
      ])
      wisp.json_response(json.to_string_tree(user_json), 200)
    }
    Error(_) -> json_error_response("No active session", 401)
  }
}

fn json_error_response(message: String, status: Int) -> Response {
  let error_json = json.object([#("error", json.string(message))])
  wisp.json_response(json.to_string_tree(error_json), status)
}

type LoginRequest {
  LoginRequest(email_address: String, password: String)
}

fn decode_login_request(data: Dynamic) -> Result(LoginRequest, String) {
  let decoder = {
    use email_address <- decode.field("email_address", decode.string)
    use password <- decode.field("password", decode.string)
    decode.success(LoginRequest(
      email_address: email_address,
      password: password,
    ))
  }
  decode.run(data, decoder)
  |> result.map_error(utils.decode_errors_to_string)
}
