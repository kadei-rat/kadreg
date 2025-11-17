import authorization
import config
import db_coordinator.{type DbCoordName}
import email
import errors
import frontend/admin_audit
import frontend/admin_dashboard
import frontend/admin_member_edit
import frontend/admin_member_view
import frontend/admin_members
import frontend/admin_stats
import frontend/dashboard
import frontend/edit_membership
import frontend/layout.{NoTables, Tables}
import frontend/login_page
import frontend/signup_page
import frontend/view_membership
import gleam/http
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri
import logging
import lustre/element
import models/admin_audit_db
import models/members
import models/members_db
import models/membership_id
import models/pending_members_db
import models/role
import session
import utils
import wisp.{type Request, type Response}

// HTML routes

pub fn static(req: Request) -> Response {
  let assert Ok(priv) = wisp.priv_directory("kadreg")
  use <- wisp.serve_static(req, under: "/static", from: priv)
  wisp.not_found()
}

// If logged in the root is the view membership, else it's the login page
pub fn root_page(req: Request, db: DbCoordName, conf: config.Config) -> Response {
  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")
  let success_msg = val_from_querystring(query_params, "success")

  case session.get_session(req) {
    Ok(_) -> view_membership(req, db, conf)
    Error(_) ->
      [login_page.view(error_msg, success_msg)]
      |> layout.view(conf.con_name, NoTables)
      |> element.to_document_string_tree
      |> wisp.html_response(200)
  }
}

pub fn signup_page(
  req: Request,
  _db: DbCoordName,
  conf: config.Config,
) -> Response {
  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")

  [signup_page.view(error_msg)]
  |> layout.view(conf.con_name, NoTables)
  |> element.to_document_string_tree
  |> wisp.html_response(200)
}

// API routes

// POST /members (Create a new pending member)
pub fn create_member(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use formdata <- wisp.require_form(req)

  decode_form_create_member_request(formdata.values)
  |> result.try(members.validate_member_request)
  |> result.try(pending_members_db.create(db, _))
  |> result.map(fn(pending_member) {
    email.send_email_confirmation_email(
      conf.base_url,
      pending_member.email_address,
      pending_member.email_confirm_token,
    )
    wisp.redirect(
      "/?success="
      <> uri.percent_encode(
        "Account created! Please check your email to confirm your address.",
      ),
    )
  })
  |> utils.spy_on_result(log_request("create_member", req, _))
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/signup?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

// Update a member - POST /members (self-edit)
pub fn update_member(
  req: Request,
  db: DbCoordName,
  membership_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)
  use formdata <- wisp.require_form(req)

  membership_id.parse(membership_id_str)
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

// POST /members/<membership_id>/delete (Delete a member)
pub fn delete_member(
  req: Request,
  db: DbCoordName,
  membership_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  // For now, default to not purging PII. (in future need to be optional, in req body or param)
  let purge_pii = False

  membership_id.parse(membership_id_str)
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

// POST /auth/login (Create a session)
pub fn login(req: Request, db: DbCoordName) -> Response {
  use formdata <- wisp.require_form(req)

  decode_form_login_request(formdata.values)
  |> result.try(fn(data) {
    members_db.authenticate(db, data.email_address, data.password)
  })
  |> utils.spy_on_result(log_request("login", req, _))
  |> result.map(fn(member) {
    wisp.redirect("/")
    |> session.create_session(req, member.membership_id, member.role)
  })
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
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
          #(
            "membership_id",
            json.string(membership_id.to_string(session_data.membership_id)),
          ),
          #("role", json.string(role.to_string(session_data.role))),
        ])
      wisp.json_response(json.to_string_tree(user_json), 200)
    }
    Error(err) -> errors.error_to_response(err)
  }
}

// GET /auth/confirm_email (Confirm email and convert pending member to member)
pub fn confirm_email(req: Request, db: DbCoordName) -> Response {
  use email <- required_val_from_querystring(req, "email")
  use token <- required_val_from_querystring(req, "token")

  percent_decode(email)
  |> result.try(pending_members_db.confirm_and_convert_to_member(db, _, token))
  |> result.map(fn(_member) {
    wisp.redirect(
      "/?success="
      <> uri.percent_encode("Email confirmed successfully! You can now log in."),
    )
  })
  |> utils.spy_on_result(log_request("confirm_email", req, _))
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

pub fn view_membership(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
) -> Response {
  use session_data <- session.require_session(req)

  members_db.get(db, session_data.membership_id)
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

  members_db.get(db, session_data.membership_id)
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

  authorization.check_manage_members(session_data)
  |> result.try(fn(_) { members_db.list(db) })
  |> result.map(fn(members_list) {
    [admin_members.view(members_list)]
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
  membership_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  membership_id.parse(membership_id_str)
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
  membership_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")

  membership_id.parse(membership_id_str)
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
  membership_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)
  use formdata <- wisp.require_form(req)

  membership_id.parse(membership_id_str)
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
    members_db.admin_update(
      db,
      session_data.membership_id,
      target_id,
      update_req,
    )
  })
  |> result.map(fn(_member) {
    wisp.redirect("/admin/members/" <> membership_id_str)
  })
  |> utils.spy_on_result(log_request("admin_update_member", req, _))
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/admin/members/"
      <> membership_id_str
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

type LoginRequest {
  LoginRequest(email_address: String, password: String)
}

fn decode_form_login_request(
  formdata: List(#(String, String)),
) -> Result(LoginRequest, errors.AppError) {
  let get_field = fn(field_name: String) -> Result(String, errors.AppError) {
    formdata
    |> utils.find_first(fn(pair) { pair.0 == field_name })
    |> result.map(fn(pair) { pair.1 })
    |> result.replace_error(errors.validation_error(
      "Missing field: " <> field_name,
      "Field missing from form data: " <> field_name,
    ))
  }

  use email_address <- result.try(get_field("email_address"))
  use password <- result.try(get_field("password"))

  case email_address == "" || password == "" {
    True ->
      Error(errors.validation_error(
        "Email and password cannot be empty",
        "Empty email or password in login request",
      ))
    False -> Ok(LoginRequest(email_address: email_address, password: password))
  }
}

fn decode_form_create_member_request(
  formdata: List(#(String, String)),
) -> Result(members.CreateMemberRequest, errors.AppError) {
  use email_address <- result.try(get_field(formdata, "email_address"))
  use handle <- result.try(get_field(formdata, "handle"))
  use password <- result.try(get_field(formdata, "password"))

  Ok(members.CreateMemberRequest(
    email_address: email_address,
    handle: handle,
    password: password,
    role: None,
  ))
}

fn decode_form_update_member_request(
  formdata: List(#(String, String)),
) -> Result(members.UpdateMemberRequest, errors.AppError) {
  use email_address <- result.try(get_field(formdata, "email_address"))
  use handle <- result.try(get_field(formdata, "handle"))
  use current_password <- result.try(get_field(formdata, "current_password"))

  let emergency_contact = case get_field(formdata, "emergency_contact") {
    Ok("") -> None
    Ok(contact) -> Some(contact)
    Error(_) -> None
  }

  // New password is optional
  let new_password = case get_field(formdata, "new_password") {
    Ok("") -> None
    Ok(password) -> Some(password)
    Error(_) -> None
  }

  Ok(members.UpdateMemberRequest(
    email_address: email_address,
    handle: handle,
    emergency_contact: emergency_contact,
    current_password: current_password,
    new_password: new_password,
  ))
}

fn decode_form_admin_update_member_request(
  formdata: List(#(String, String)),
) -> Result(members.AdminUpdateMemberRequest, errors.AppError) {
  use email_address <- result.try(get_field(formdata, "email_address"))
  use handle <- result.try(get_field(formdata, "handle"))
  use role_str <- result.try(get_field(formdata, "role"))

  let emergency_contact = case get_field(formdata, "emergency_contact") {
    Ok("") -> None
    Ok(contact) -> Some(contact)
    Error(_) -> None
  }

  use role <- result.try(role.from_string(role_str))

  Ok(members.AdminUpdateMemberRequest(
    email_address: email_address,
    handle: handle,
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

fn required_val_from_querystring(
  req: Request,
  key: String,
  next: fn(String) -> Response,
) -> Response {
  let query_params = wisp.get_query(req)
  case query_params |> utils.find_first(fn(pair) { pair.0 == key }) {
    Ok(#(_, msg)) -> next(msg)
    Error(_) -> {
      log_request(
        req.path,
        req,
        Error(errors.validation_error("", "Missing query parameter: " <> key)),
      )
      wisp.redirect(
        "/?error=" <> uri.percent_encode("Missing query parameter: " <> key),
      )
    }
  }
}

fn percent_decode(val: String) -> Result(String, errors.AppError) {
  uri.percent_decode(val)
  |> result.replace_error(errors.validation_error(
    "Malformed percent-encoded value",
    "Failed to percent-decode value: " <> val,
  ))
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
