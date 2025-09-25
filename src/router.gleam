import config
import db_coordinator.{type DbCoordName}
import gleam/http.{Get, Patch, Post}
import handlers
import wisp.{type Request, type Response}

pub fn handle_request(
  req: Request,
  conf: config.Config,
  db: DbCoordName,
) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req), req.method {
    // static files
    ["static", ..], Get -> handlers.static(req)

    // html
    [], Get -> handlers.root_page(req, db, conf)
    ["signup"], Get -> handlers.signup_page(req, db, conf)
    ["membership", "edit"], Get -> handlers.edit_membership(req, db, conf)

    // admin
    ["admin"], Get -> handlers.admin_stats(req, db, conf)
    ["admin", "members"], Get -> handlers.admin_members_list(req, db, conf)
    ["admin", "members", membership_id], Get ->
      handlers.admin_member_view(req, db, conf, membership_id)
    ["admin", "members", membership_id, "edit"], Get ->
      handlers.admin_member_edit_page(req, db, conf, membership_id)

    // api
    ["auth", "login"], Post -> handlers.login(req, db)
    ["auth", "logout"], Post -> handlers.logout(req, db)
    ["auth", "me"], Get -> handlers.me(req, db)
    ["members"], Post -> handlers.create_member(req, db, conf)
    ["members", membership_id], Patch ->
      handlers.update_member(req, db, membership_id)
    ["members", membership_id, "delete"], Post ->
      handlers.delete_member(req, db, membership_id)
    ["admin", "members", membership_id], Patch ->
      handlers.admin_update_member(req, db, conf, membership_id)

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
