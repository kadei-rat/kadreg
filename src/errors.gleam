import gleam/json
import wisp.{type Response}

pub type AppError {
  AuthorizationError(String)  // 403 - User lacks permission
  AuthenticationError(String) // 401 - User not authenticated or invalid session
  ValidationError(String)     // 400 - Bad request data  
  NotFoundError(String)       // 404 - Resource doesn't exist
  InternalError(String)       // 500 - Server/database errors
}

pub fn error_to_response(error: AppError) -> Response {
  case error {
    AuthorizationError(msg) -> json_error_response(msg, 403)
    AuthenticationError(msg) -> json_error_response(msg, 401)
    ValidationError(msg) -> json_error_response(msg, 400)
    NotFoundError(msg) -> json_error_response(msg, 404)
    InternalError(msg) -> json_error_response(msg, 500)
  }
}

fn json_error_response(message: String, status: Int) -> Response {
  let error_json = json.object([#("error", json.string(message))])
  wisp.json_response(json.to_string_tree(error_json), status)
}

// Convenience constructors
pub fn authorization_error(message: String) -> AppError {
  AuthorizationError(message)
}

pub fn authentication_error(message: String) -> AppError {
  AuthenticationError(message)
}

pub fn validation_error(message: String) -> AppError {
  ValidationError(message)
}

pub fn not_found_error(message: String) -> AppError {
  NotFoundError(message)
}

pub fn internal_error(message: String) -> AppError {
  InternalError(message)
}