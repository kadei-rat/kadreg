import authorization
import config
import errors
import frontend/layout
import frontend/login_page
import frontend/signup_page
import gleam/http
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri
import logging
import lustre/element
import models/members
import models/membership_id
import models/role
import pog
import session
import utils
import wisp.{type Request, type Response}

// HTML routes

pub fn static(req: Request) -> Response {
  let assert Ok(priv) = wisp.priv_directory("kadreg")
  use <- wisp.serve_static(req, under: "/static", from: priv)
  wisp.not_found()
}

pub fn login_page(
  req: Request,
  _db: pog.Connection,
  conf: config.Config,
) -> Response {
  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")
  let success_msg = val_from_querystring(query_params, "success")

  [login_page.root(error_msg, success_msg)]
  |> layout.layout(conf.con_name)
  |> element.to_document_string_tree
  |> wisp.html_response(200)
}

pub fn signup_page(
  req: Request,
  _db: pog.Connection,
  conf: config.Config,
) -> Response {
  let query_params = wisp.get_query(req)
  let error_msg = val_from_querystring(query_params, "error")

  [signup_page.root(error_msg)]
  |> layout.layout(conf.con_name)
  |> element.to_document_string_tree
  |> wisp.html_response(200)
}

// API routes

// POST /members (Create a new member)
pub fn create_member(
  req: Request,
  db: pog.Connection,
  _conf: config.Config,
) -> Response {
  use formdata <- wisp.require_form(req)

  decode_form_create_member_request(formdata.values)
  |> result.try(members.validate_member_request)
  |> result.try(members.create(db, _))
  |> result.map(fn(_member) {
    wisp.redirect(
      "/?success="
      <> uri.percent_encode("Account created successfully! Please login."),
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

// GET /members/<membership_id> (Get a specific member)
pub fn get_member(
  req: Request,
  db: pog.Connection,
  membership_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  membership_id.parse(membership_id_str)
  |> result.try(fn(target_id) {
    authorization.can_manage_member_details(session_data, target_id)
    |> result.replace(target_id)
  })
  |> result.try(members.get(db, _))
  |> result.map(members.to_json)
  |> result.map(json.to_string_tree)
  |> utils.spy_on_result(log_request("get_member", req, _))
  |> result.map(wisp.json_response(_, 200))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

// GET /members (List all members)
pub fn list_members(req: Request, db: pog.Connection) -> Response {
  use session_data <- session.require_session(req)

  authorization.can_list_members(session_data)
  |> result.try(fn(_) { members.list(db) })
  |> result.map(json.array(_, members.to_json))
  |> result.map(json.to_string_tree)
  |> result.map(wisp.json_response(_, 200))
  |> utils.spy_on_result(log_request("list_members", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

// Update a member - PATCH /members
pub fn update_member(req: Request, _db: pog.Connection) -> Response {
  use _body <- wisp.require_json(req)

  let error_json =
    json.object([#("error", json.string("Update not yet implemented"))])
  wisp.json_response(json.to_string_tree(error_json), 501)
}

// POST /members/<membership_id>/delete (Delete a member)
pub fn delete_member(
  req: Request,
  db: pog.Connection,
  membership_id_str: String,
) -> Response {
  use session_data <- session.require_session(req)

  // For now, default to not purging PII. (in future need to be optional, in req body or param)
  let purge_pii = False

  membership_id.parse(membership_id_str)
  |> result.try(fn(target_id) {
    authorization.can_manage_member_details(session_data, target_id)
    |> result.replace(target_id)
  })
  |> result.try(members.delete(db, _, purge_pii))
  |> result.map(fn(_) { wisp.ok() })
  |> utils.spy_on_result(log_request("delete_member", req, _))
  |> result.map_error(errors.error_to_response)
  |> result.unwrap_both
}

// POST /auth/login (Create a session)
pub fn login(req: Request, db: pog.Connection) -> Response {
  use formdata <- wisp.require_form(req)

  decode_form_login_request(formdata.values)
  |> result.try(fn(data) {
    members.authenticate(db, data.email_address, data.password)
  })
  |> result.map(fn(member) {
    wisp.redirect("/auth/me")
    |> session.create_session(req, member.membership_id, member.role)
  })
  |> utils.spy_on_result(log_request("login", req, _))
  |> result.map_error(fn(err) {
    wisp.redirect(
      "/?error=" <> uri.percent_encode(errors.to_public_string(err)),
    )
  })
  |> result.unwrap_both
}

// POST /auth/logout (Destroy session)
pub fn logout(req: Request, _db: pog.Connection) -> Response {
  let success_json =
    json.object([#("message", json.string("Logout successful"))])
  wisp.json_response(json.to_string_tree(success_json), 200)
  |> session.destroy_session(req)
}

// GET /auth/me (Get current session info)
pub fn me(req: Request, _db: pog.Connection) -> Response {
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
  use legal_name <- result.try(get_field(formdata, "legal_name"))
  use date_of_birth <- result.try(get_field(formdata, "date_of_birth"))
  use handle <- result.try(get_field(formdata, "handle"))
  use postal_address <- result.try(get_field(formdata, "postal_address"))
  use phone_number <- result.try(get_field(formdata, "phone_number"))
  use password <- result.try(get_field(formdata, "password"))

  Ok(members.CreateMemberRequest(
    email_address: email_address,
    legal_name: legal_name,
    date_of_birth: date_of_birth,
    handle: handle,
    postal_address: postal_address,
    phone_number: phone_number,
    password: password,
    role: None,
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
