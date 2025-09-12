import gleam/json
import models/membership_id.{type MembershipId}
import wisp.{type Request, type Response}

pub type SessionError {
  InvalidSession
  NoSession
}

const session_cookie_name = "kadreg_session"
const session_duration = 86400

pub fn create_session(
  response: Response,
  request: Request,
  membership_id: MembershipId,
) -> Response {
  wisp.set_cookie(
    response,
    request,
    session_cookie_name,
    membership_id.to_string(membership_id),
    wisp.Signed,
    session_duration,
  )
}

pub fn get_session(request: Request) -> Result(MembershipId, SessionError) {
  case wisp.get_cookie(request, session_cookie_name, wisp.Signed) {
    Ok(membership_id_str) -> {
      case membership_id.parse(membership_id_str) {
        Ok(membership_id) -> Ok(membership_id)
        Error(_) -> Error(InvalidSession)
      }
    }
    Error(_) -> Error(NoSession)
  }
}

pub fn destroy_session(response: Response, request: Request) -> Response {
  wisp.set_cookie(response, request, session_cookie_name, "", wisp.Signed, 0)
}

pub fn require_session(
  request: Request,
  handler: fn(Request, MembershipId) -> Response,
) -> Response {
  case get_session(request) {
    Ok(membership_id) -> handler(request, membership_id)
    Error(_) -> {
      let error_json = json.object([#("error", json.string("Authentication required"))])
      wisp.json_response(json.to_string_tree(error_json), 401)
    }
  }
}