import errors.{type AppError}
import gleam/int
import gleam/string
import models/role.{type Role}
import wisp.{type Request, type Response}

pub type SessionData {
  SessionData(telegram_id: Int, role: Role)
}

const session_cookie_name = "kadreg_session"

const session_duration = 86_400

pub fn create_session(
  response: Response,
  request: Request,
  telegram_id: Int,
  role: Role,
) -> Response {
  let session_value = int.to_string(telegram_id) <> ":" <> role.to_string(role)
  wisp.set_cookie(
    response,
    request,
    session_cookie_name,
    session_value,
    wisp.Signed,
    session_duration,
  )
}

pub fn get_session(request: Request) -> Result(SessionData, AppError) {
  case wisp.get_cookie(request, session_cookie_name, wisp.Signed) {
    Ok(session_value) -> parse_session_value(session_value)
    Error(_) -> Error(errors.authentication_error("No session found"))
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
    Error(_) ->
      errors.error_to_response(errors.authentication_error(
        "Authentication required",
      ))
  }
}

fn parse_session_value(session_value: String) -> Result(SessionData, AppError) {
  case string.split_once(session_value, ":") {
    Ok(#(telegram_id_str, role_str)) -> {
      case int.parse(telegram_id_str), role.from_string(role_str) {
        Ok(telegram_id), Ok(role) -> Ok(SessionData(telegram_id, role))
        _, _ -> Error(errors.authentication_error("Invalid session format"))
      }
    }
    Error(_) -> Error(errors.authentication_error("Invalid session format"))
  }
}
