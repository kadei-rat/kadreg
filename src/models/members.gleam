import errors.{type AppError}
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/string
import models/membership_id.{type MembershipId}
import models/role.{type Role}

// Types

pub type MemberRecord {
  MemberRecord(
    membership_num: Int,
    membership_id: MembershipId,
    email_address: String,
    legal_name: String,
    date_of_birth: String,
    handle: String,
    postal_address: String,
    phone_number: String,
    password_hash: String,
    role: Role,
    created_at: String,
    updated_at: String,
    deleted_at: Option(String),
  )
}

pub type CreateMemberRequest {
  CreateMemberRequest(
    email_address: String,
    legal_name: String,
    date_of_birth: String,
    handle: String,
    postal_address: String,
    phone_number: String,
    password: String,
    role: Option(Role),
  )
}

pub type DeleteMemberRequest {
  DeleteMemberRequest(
    membership_id: MembershipId,
    // Whether to replace PII with "(deleted)"
    purge_pii: Bool,
  )
}

pub type UpdateMemberRequest {
  UpdateMemberRequest(
    email_address: String,
    legal_name: String,
    handle: String,
    postal_address: String,
    phone_number: String,
    current_password: String,
    new_password: Option(String),
  )
}

// Admin one differs from regular update by allowing role changes and DoB
// changes, but not allowing password changes
pub type AdminUpdateMemberRequest {
  AdminUpdateMemberRequest(
    email_address: String,
    legal_name: String,
    date_of_birth: String,
    handle: String,
    postal_address: String,
    phone_number: String,
    role: Role,
  )
}

pub type MemberStats {
  MemberStats(
    total_members: Int,
    recent_signups: Int,
    total_staff: Int,
    total_deleted: Int,
  )
}

pub fn validate_member_request(
  req: CreateMemberRequest,
) -> Result(CreateMemberRequest, AppError) {
  let validations = [
    validate(string.contains(req.email_address, "@"), "Invalid email address"),
    validate(req.legal_name != "", "Must specify a legal name"),
    validate(req.phone_number != "", "Must specify a phone number"),
    validate(req.handle != "", "Must specify a handle"),
    validate(req.postal_address != "", "Must specify a postal address"),
    validate(req.date_of_birth != "", "Must specify a date of birth"),
    validate(
      string.length(req.password) >= 12,
      "Password must be at least 12 characters",
    ),
  ]

  result.all(validations)
  |> result.map(fn(_) { req })
}

fn validate(result: Bool, err_msg: String) -> Result(Nil, AppError) {
  case result {
    True -> Ok(Nil)
    False -> Error(errors.validation_error(err_msg, err_msg))
  }
}

pub fn member_to_json(member: MemberRecord) -> json.Json {
  json.object([
    #("email_address", json.string(member.email_address)),
    #("legal_name", json.string(member.legal_name)),
    #("date_of_birth", json.string(member.date_of_birth)),
    #("handle", json.string(member.handle)),
    #("postal_address", json.string(member.postal_address)),
    #("phone_number", json.string(member.phone_number)),
    #("role", json.string(role.to_string(member.role))),
  ])
}
