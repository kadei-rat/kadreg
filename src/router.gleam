import config
import db_coordinator.{type DbCoordName}
import gleam/http.{Get, Post}
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
    ["membership", "edit"], Get -> handlers.edit_membership(req, db, conf)
    ["register"], Get -> handlers.register_page(req, db, conf)

    // admin
    ["admin"], Get -> handlers.admin_stats(req, db, conf)
    ["admin", "audit"], Get -> handlers.admin_audit_log(req, db, conf)
    ["admin", "members"], Get -> handlers.admin_members_list(req, db, conf)
    ["admin", "registrations"], Get ->
      handlers.admin_registrations_list(req, db, conf)
    ["admin", "registrations", telegram_id, "edit"], Get ->
      handlers.admin_registration_edit_page(req, db, conf, telegram_id)
    ["admin", "members", telegram_id], Get ->
      handlers.admin_member_view(req, db, conf, telegram_id)
    ["admin", "members", telegram_id, "edit"], Get ->
      handlers.admin_member_edit_page(req, db, conf, telegram_id)

    // auth api
    ["auth", "telegram_callback"], Get ->
      handlers.telegram_callback(req, db, conf)
    ["auth", "dev_login"], Get -> handlers.dev_login(req, db, conf)
    ["auth", "logout"], Post -> handlers.logout(req, db)
    ["auth", "me"], Get -> handlers.me(req, db)

    // member api
    ["members", telegram_id], Post ->
      handlers.update_member(req, db, telegram_id)
    ["members", telegram_id, "delete"], Post ->
      handlers.delete_member(req, db, telegram_id)
    ["admin", "members", telegram_id], Post ->
      handlers.admin_update_member(req, db, conf, telegram_id)
    ["admin", "registrations", telegram_id], Post ->
      handlers.admin_update_registration(req, db, conf, telegram_id)

    // registration api
    ["registrations"], Post -> handlers.create_registration(req, db, conf)
    ["registrations", convention_id], Post ->
      handlers.update_registration(req, db, conf, convention_id)
    ["registrations", convention_id, "cancel"], Post ->
      handlers.cancel_registration(req, db, conf, convention_id)

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
  |> wisp.set_header("access-control-allow-methods", "GET, POST, OPTIONS")
  |> wisp.set_header(
    "access-control-allow-headers",
    "Content-Type, Authorization",
  )
}
