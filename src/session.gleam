import gleam/json
import gleam/string
import models/membership_id.{type MembershipId}
import models/role.{type Role}
import wisp.{type Request, type Response}

pub type SessionData {
  SessionData(membership_id: MembershipId, role: Role)
}

pub type SessionError {
  InvalidSession
  NoSession
}

const session_cookie_name = "kadreg_session"

const session_duration = 86_400

pub fn create_session(
  response: Response,
  request: Request,
  membership_id: MembershipId,
  role: Role,
) -> Response {
  let session_value =
    membership_id.to_string(membership_id) <> ":" <> role.to_string(role)
  wisp.set_cookie(
    response,
    request,
    session_cookie_name,
    session_value,
    wisp.Signed,
    session_duration,
  )
}

pub fn get_session(request: Request) -> Result(SessionData, SessionError) {
  case wisp.get_cookie(request, session_cookie_name, wisp.Signed) {
    Ok(session_value) -> parse_session_value(session_value)
    Error(_) -> Error(NoSession)
  }
}

pub fn destroy_session(response: Response, request: Request) -> Response {
  wisp.set_cookie(response, request, session_cookie_name, "", wisp.Signed, 0)
}

pub fn require_session(
  request: Request,
  next: fn(SessionData) -> Response,
) -> Response {
  case get_session(request) {
    Ok(session_data) -> next(session_data)
    Error(_) -> {
      let error_json =
        json.object([#("error", json.string("Authentication required"))])
      wisp.json_response(json.to_string_tree(error_json), 401)
    }
  }
}

fn parse_session_value(
  session_value: String,
) -> Result(SessionData, SessionError) {
  case string.split_once(session_value, ":") {
    Ok(#(membership_id_str, role_str)) -> {
      case membership_id.parse(membership_id_str), role.from_string(role_str) {
        Ok(membership_id), Ok(role) -> Ok(SessionData(membership_id, role))
        _, _ -> Error(InvalidSession)
      }
    }
    Error(_) -> Error(InvalidSession)
  }
}
