import gleam/http.{Get, Patch, Post}
import handlers
import pog
import session
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, db: pog.Connection) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req), req.method {
    // Authentication routes (no session required)
    ["auth", "login"], Post -> handlers.login_handler(req, db)
    ["auth", "logout"], Post -> handlers.logout_handler(req, db)
    ["auth", "me"], Get -> handlers.me_handler(req, db)

    // Protected member routes (session required)
    ["members"], Post ->
      session.require_session(req, fn(req, _session_membership_id) {
        handlers.create_member_handler(req, db)
      })

    ["members"], Get ->
      session.require_session(req, fn(req, _session_membership_id) {
        handlers.list_members_handler(req, db)
      })

    ["members"], Patch ->
      session.require_session(req, fn(req, _session_membership_id) {
        handlers.update_member_handler(req, db)
      })

    ["members", membership_id], Get ->
      session.require_session(req, fn(req, _session_membership_id) {
        handlers.get_member_handler(req, db, membership_id)
      })

    ["members", membership_id, "delete"], Post ->
      session.require_session(req, fn(req, _session_membership_id) {
        handlers.delete_member_handler(req, db, membership_id)
      })

    // Health check (no session required)
    ["health"], Get -> {
      wisp.response(200)
      |> wisp.string_body("OK")
    }

    _, _ ->
      wisp.response(404)
      |> wisp.string_body("Not Found")
  }
}

fn middleware(req: Request, handle_request: fn(Request) -> Response) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- cors_middleware

  handle_request(req)
}

fn cors_middleware(handle_request: fn() -> Response) -> Response {
  handle_request()
  |> wisp.set_header("access-control-allow-origin", "*")
  |> wisp.set_header(
    "access-control-allow-methods",
    "GET, POST, PATCH, DELETE, OPTIONS",
  )
  |> wisp.set_header(
    "access-control-allow-headers",
    "Content-Type, Authorization",
  )
}
