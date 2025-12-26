import authorization
import config
import db_coordinator.{type DbCoordName}
import errors
import frontend/admin_audit
import frontend/admin_dashboard
import frontend/admin_member_edit
import frontend/admin_member_view
import frontend/admin_members
import frontend/admin_registration_edit
import frontend/admin_registrations
import frontend/admin_stats
import frontend/dashboard
import frontend/edit_membership
import frontend/layout.{NoTables, Tables}
import frontend/login_page
import frontend/register
import frontend/view_membership
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri
import logging
import lustre/element
import models/admin_audit_db
import models/conventions
import models/members
import models/members_db
import models/registrations
import models/registrations_db
import models/role
import session
import telegram_auth
import utils
import wisp.{type Request, type Response}

// HTML routes

pub fn static(req: Request) -> Response {
  let assert Ok(priv) = wisp.priv_directory("kadreg")
  use <- wisp.serve_static(req, under: "/static", from: priv)
  wisp.not_found()
}

pub fn root_page(req: Request, db: DbCoordName, conf: config.Config) -> Response {
  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")
  let success_msg = val_from_querystring(query_params, "success")

  case session.get_session(req) {
    Ok(_) -> view_membership(req, db, conf)
    Error(_) ->
      [login_page.view(conf.telegram_bot_username, error_msg, success_msg)]
      |> layout.view(conf.con_name, NoTables)
      |> element.to_document_string_tree
      |> wisp.html_response(200)
  }
}

// API routes

pub fn update_member(
  req: Request,
  db: DbCoordName,
  telegram_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)
  use formdata <- wisp.require_form(req)

  parse_telegram_id(telegram_id_str)
  |> result.try(fn(target_id) {
    authorization.check_manage_member_details(session_data, target_id)
    |> result.replace(target_id)
  })
  |> result.try(fn(target_id) {
    decode_form_update_member_request(formdata.values)
    |> result.map(fn(update_req) { #(target_id, update_req) })
  })
  |> result.try(fn(data) {
    let #(target_id, update_req) = data
    members_db.update_profile(db, target_id, update_req)
  })
  |> utils.spy_on_result(log_request("update_member", req, _))
  |> result.map(fn(_member) { wisp.redirect("/") })
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/membership/edit?error="
      <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

pub fn delete_member(
  req: Request,
  db: DbCoordName,
  telegram_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  let purge_pii = False

  parse_telegram_id(telegram_id_str)
  |> result.try(fn(target_id) {
    authorization.check_manage_member_details(session_data, target_id)
    |> result.replace(target_id)
  })
  |> result.try(members_db.delete(db, _, purge_pii))
  |> utils.spy_on_result(log_request("delete_member", req, _))
  |> result.map(fn(_) { wisp.ok() })
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

// GET /auth/telegram_callback - Handle Telegram login widget callback
pub fn telegram_callback(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  let query_params = wisp.get_query(req)

  telegram_auth.verify_login(query_params, conf.telegram_bot_token)
  |> result.try(fn(login_data) {
    let auth_data =
      members_db.TelegramAuthData(
        telegram_id: login_data.id,
        first_name: login_data.first_name,
        username: login_data.username,
      )
    members_db.upsert_from_telegram(db, auth_data)
  })
  |> utils.spy_on_result(log_request("telegram_callback", req, _))
  |> result.map(fn(member) {
    wisp.redirect("/")
    |> session.create_session(req, member.telegram_id, member.role)
  })
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

// GET /auth/dev_login - Dev-only bypass for local testing
pub fn dev_login(req: Request, db: DbCoordName, conf: config.Config) -> Response {
  case conf.kadreg_env {
    config.Prod ->
      wisp.response(404)
      |> wisp.string_body("Not found")
    config.Dev -> {
      let auth_data =
        members_db.TelegramAuthData(
          telegram_id: 12_345_678,
          first_name: "Dev User",
          username: Some("devuser"),
        )
      case members_db.upsert_from_telegram(db, auth_data) {
        Ok(member) ->
          wisp.redirect("/")
          |> session.create_session(req, member.telegram_id, member.role)
        Error(_) -> wisp.redirect("/?error=Dev login failed")
      }
    }
  }
}

// POST /auth/logout (Destroy session)
pub fn logout(req: Request, _db: DbCoordName) -> Response {
  wisp.redirect("/?success=" <> uri.percent_encode("Logged out successfully."))
  |> session.destroy_session(req)
}

// GET /auth/me (Get current session info)
pub fn me(req: Request, _db: DbCoordName) -> Response {
  let result = session.get_session(req)
  log_request("me", req, result)
  case result {
    Ok(session_data) -> {
      let user_json =
        json.object([
          #("telegram_id", json.int(session_data.telegram_id)),
          #("role", json.string(role.to_string(session_data.role))),
        ])
      wisp.json_response(json.to_string_tree(user_json), 200)
    }
    Error(err) -> errors.error_to_response(err)
  }
}

pub fn view_membership(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)

  members_db.get(db, session_data.telegram_id)
  |> result.map(fn(member) {
    [view_membership.view(member)]
    |> dashboard.view(req.path, authorization.can_access_admin(session_data))
    |> layout.view(conf.con_name, NoTables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("view_membership", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn edit_membership(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)
  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")

  members_db.get(db, session_data.telegram_id)
  |> result.map(fn(member) {
    [edit_membership.dashboard_edit_page(member, error_msg)]
    |> dashboard.view(req.path, authorization.can_access_admin(session_data))
    |> layout.view(conf.con_name, NoTables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("edit_membership", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

// Admin routes

pub fn admin_stats(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)

  authorization.check_access_admin(session_data)
  |> result.try(fn(_) { members_db.get_stats(db) })
  |> result.map(fn(stats) {
    [admin_stats.view(stats)]
    |> admin_dashboard.view(req.path)
    |> layout.view(conf.con_name, NoTables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("admin_stats", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn admin_members_list(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)

  let convention = conventions.current_convention

  authorization.check_manage_members(session_data)
  |> result.try(fn(_) { members_db.list(db) })
  |> result.try(fn(members_list) {
    registrations_db.get_status_map_for_convention(db, convention.id)
    |> result.map(fn(reg_statuses) { #(members_list, reg_statuses) })
  })
  |> result.map(fn(data) {
    let #(members_list, reg_statuses) = data
    [admin_members.view(members_list, reg_statuses)]
    |> admin_dashboard.view(req.path)
    |> layout.view(conf.con_name, Tables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("admin_members_list", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn admin_member_view(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
  telegram_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  parse_telegram_id(telegram_id_str)
  |> result.try(fn(target_id) {
    authorization.check_manage_member_details(session_data, target_id)
    |> result.replace(target_id)
  })
  |> result.try(members_db.get(db, _))
  |> result.map(fn(member) {
    [admin_member_view.view(member)]
    |> admin_dashboard.view(req.path)
    |> layout.view(conf.con_name, NoTables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("admin_member_view", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn admin_member_edit_page(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
  telegram_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")

  parse_telegram_id(telegram_id_str)
  |> result.try(fn(target_id) {
    authorization.check_manage_member_details(session_data, target_id)
    |> result.replace(target_id)
  })
  |> result.try(members_db.get(db, _))
  |> result.map(fn(member) {
    [admin_member_edit.member_edit_page(member, error_msg)]
    |> admin_dashboard.view(req.path)
    |> layout.view(conf.con_name, NoTables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("admin_member_edit", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn admin_update_member(
  req: Request,
  db: DbCoordName,
  _conf: config.Config,
  telegram_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)
  use formdata <- wisp.require_form(req)

  parse_telegram_id(telegram_id_str)
  |> result.try(fn(target_id) {
    authorization.check_manage_member_details(session_data, target_id)
    |> result.replace(target_id)
  })
  |> result.try(fn(target_id) {
    decode_form_admin_update_member_request(formdata.values)
    |> result.map(fn(update_req) { #(target_id, update_req) })
  })
  |> result.try(fn(data) {
    let #(target_id, update_req) = data
    members_db.admin_update(db, session_data.telegram_id, target_id, update_req)
  })
  |> result.map(fn(_member) {
    wisp.redirect("/admin/members/" <> telegram_id_str)
  })
  |> utils.spy_on_result(log_request("admin_update_member", req, _))
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/admin/members/"
      <> telegram_id_str
      <> "/edit?error="
      <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

pub fn admin_audit_log(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)

  authorization.check_manage_members(session_data)
  |> result.try(fn(_) { admin_audit_db.get_actions(db) })
  |> result.map(fn(audit_entries) {
    [admin_audit.view(audit_entries)]
    |> admin_dashboard.view(req.path)
    |> layout.view(conf.con_name, Tables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("admin_audit_log", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn admin_registrations_list(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)

  let convention = conventions.current_convention

  authorization.check_manage_members(session_data)
  |> result.try(fn(_) {
    registrations_db.list_for_convention_with_members(db, convention.id)
  })
  |> result.map(fn(regs) {
    [admin_registrations.view(convention, regs)]
    |> admin_dashboard.view(req.path)
    |> layout.view(conf.con_name, Tables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("admin_registrations_list", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn admin_registration_edit_page(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
  telegram_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")
  let convention = conventions.current_convention

  authorization.check_manage_members(session_data)
  |> result.try(fn(_) { parse_telegram_id(telegram_id_str) })
  |> result.try(fn(member_id) {
    registrations_db.get_with_member(db, member_id, convention.id)
  })
  |> result.map(fn(reg_with_member) {
    let reg =
      registrations.Registration(
        member_id: reg_with_member.member_id,
        convention_id: reg_with_member.convention_id,
        tier: reg_with_member.tier,
        status: reg_with_member.status,
        created_at: reg_with_member.created_at,
        updated_at: reg_with_member.updated_at,
      )
    let display_name = case reg_with_member.username {
      Some(u) -> u
      None -> reg_with_member.first_name
    }
    [admin_registration_edit.view(convention, reg, display_name, error_msg)]
    |> admin_dashboard.view(req.path)
    |> layout.view(conf.con_name, NoTables)
    |> element.to_document_string_tree
    |> wisp.html_response(200)
  })
  |> utils.spy_on_result(log_request("admin_registration_edit_page", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

pub fn admin_update_registration(
  req: Request,
  db: DbCoordName,
  _conf: config.Config,
  telegram_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)
  use formdata <- wisp.require_form(req)

  let convention = conventions.current_convention

  authorization.check_manage_members(session_data)
  |> result.try(fn(_) { parse_telegram_id(telegram_id_str) })
  |> result.try(fn(member_id) {
    use tier_str <- result.try(get_field(formdata.values, "tier"))
    use status_str <- result.try(get_field(formdata.values, "status"))
    use tier <- result.try(registrations.tier_from_string(tier_str))
    use status <- result.try(registrations.status_from_string(status_str))

    registrations_db.admin_update(db, member_id, convention.id, tier, status)
  })
  |> utils.spy_on_result(log_request("admin_update_registration", req, _))
  |> result.map(fn(_) { wisp.redirect("/admin/registrations") })
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/admin/registrations/"
      <> telegram_id_str
      <> "/edit?error="
      <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

// Registration routes

pub fn register_page(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)

  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")
  let convention = conventions.current_convention

  let registration =
    registrations_db.get(db, session_data.telegram_id, convention.id)
    |> option.from_result

  [register.view(convention, registration, conf.registration_open, error_msg)]
  |> dashboard.view(req.path, authorization.can_access_admin(session_data))
  |> layout.view(conf.con_name, NoTables)
  |> element.to_document_string_tree
  |> wisp.html_response(200)
}

pub fn create_registration(
  req: Request,
  db: DbCoordName,
  _conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)
  use formdata <- wisp.require_form(req)

  {
    use convention_id <- result.try(get_field(formdata.values, "convention_id"))
    use tier_str <- result.try(get_field(formdata.values, "tier"))
    use tier <- result.try(registrations.tier_from_string(tier_str))

    registrations_db.create(db, session_data.telegram_id, convention_id, tier)
  }
  |> utils.spy_on_result(log_request("create_registration", req, _))
  |> result.map(fn(_) { wisp.redirect("/register") })
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/register?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

pub fn update_registration(
  req: Request,
  db: DbCoordName,
  _conf: config.Config,
  convention_id: String,
) -> Response {
  use session_data <- session.require_session(req)
  use formdata <- wisp.require_form(req)

  {
    use reg <- result.try(registrations_db.get(
      db,
      session_data.telegram_id,
      convention_id,
    ))
    case registrations.can_user_modify(reg.status) {
      False ->
        Error(errors.authorization_error(
          "Cannot modify a registration in the "
          <> registrations.status_to_display_string(reg.status)
          <> " state",
        ))
      True -> Ok(Nil)
    }
  }
  |> result.try(fn(_) {
    use tier_str <- result.try(get_field(formdata.values, "tier"))
    use tier <- result.try(registrations.tier_from_string(tier_str))

    registrations_db.update_tier(
      db,
      session_data.telegram_id,
      convention_id,
      tier,
    )
  })
  |> utils.spy_on_result(log_request("update_registration", req, _))
  |> result.map(fn(_) { wisp.redirect("/register") })
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/register?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

pub fn cancel_registration(
  req: Request,
  db: DbCoordName,
  _conf: config.Config,
  convention_id: String,
) -> Response {
  use session_data <- session.require_session(req)

  {
    use reg <- result.try(registrations_db.get(
      db,
      session_data.telegram_id,
      convention_id,
    ))
    case registrations.can_user_modify(reg.status) {
      False ->
        Error(errors.authorization_error(
          "Cannot cancel a registration in the "
          <> registrations.status_to_display_string(reg.status)
          <> " state",
        ))
      True -> Ok(Nil)
    }
  }
  |> result.try(fn(_) {
    registrations_db.cancel(db, session_data.telegram_id, convention_id)
  })
  |> utils.spy_on_result(log_request("cancel_registration", req, _))
  |> result.map(fn(_) { wisp.redirect("/register") })
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/register?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

// Helpers

fn log_request(
  handler_name: String,
  req: Request,
  result: Result(a, errors.AppError),
) -> Nil {
  let method = http.method_to_string(req.method)
  let path = req.path

  let message = case result {
    Error(err) -> {
      let error_details = errors.to_internal_string(err)
      method <> " " <> path <> " (" <> handler_name <> ") - " <> error_details
    }
    Ok(_) -> method <> " " <> path <> " (" <> handler_name <> ") - success :D"
  }

  logging.log(logging.Info, message)
}

fn parse_telegram_id(id_str: String) -> Result(Int, errors.AppError) {
  int.parse(id_str)
  |> result.replace_error(errors.validation_error(
    "Invalid member ID",
    "Failed to parse telegram_id: " <> id_str,
  ))
}

fn decode_form_update_member_request(
  formdata: List(#(String, String)),
) -> Result(members.UpdateMemberRequest, errors.AppError) {
  let emergency_contact = case get_field(formdata, "emergency_contact") {
    Ok("") -> None
    Ok(contact) -> Some(contact)
    Error(_) -> None
  }

  Ok(members.UpdateMemberRequest(emergency_contact: emergency_contact))
}

fn decode_form_admin_update_member_request(
  formdata: List(#(String, String)),
) -> Result(members.AdminUpdateMemberRequest, errors.AppError) {
  use first_name <- result.try(get_field(formdata, "first_name"))
  use role_str <- result.try(get_field(formdata, "role"))

  let username = case get_field(formdata, "username") {
    Ok("") -> None
    Ok(u) -> Some(u)
    Error(_) -> None
  }

  let emergency_contact = case get_field(formdata, "emergency_contact") {
    Ok("") -> None
    Ok(contact) -> Some(contact)
    Error(_) -> None
  }

  use role <- result.try(role.from_string(role_str))

  Ok(members.AdminUpdateMemberRequest(
    first_name: first_name,
    username: username,
    emergency_contact: emergency_contact,
    role: role,
  ))
}

fn val_from_querystring(
  query_params: List(#(String, String)),
  key: String,
) -> Option(String) {
  case query_params |> utils.find_first(fn(pair) { pair.0 == key }) {
    Ok(#(_, msg)) -> Some(msg)
    Error(_) -> None
  }
}

fn get_field(
  formdata: List(#(String, String)),
  field_name: String,
) -> Result(String, errors.AppError) {
  formdata
  |> utils.find_first(fn(pair) { pair.0 == field_name })
  |> result.map(fn(pair) { pair.1 })
  |> result.replace_error(errors.validation_error(
    "Missing field: " <> field_name,
    "Field missing from form data: " <> field_name,
  ))
}
