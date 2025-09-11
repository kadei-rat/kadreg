import birl.{type Time}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import models/membership_id.{type MembershipId}
import models/role.{type Role}
import pog

// Types

pub type MemberRecord {
  MemberRecord(
    membership_num: Int,
    membership_id: MembershipId,
    email_address: String,
    legal_name: String,
    // ISO date string
    date_of_birth: String,
    handle: String,
    postal_address: String,
    phone_number: String,
    role: Role,
    created_at: Time,
    updated_at: Time,
    deleted_at: Option(Time),
  )
}

pub type CreateMemberRequest {
  CreateMemberRequest(
    email_address: String,
    legal_name: String,
    // ISO date string
    date_of_birth: String,
    handle: String,
    postal_address: String,
    phone_number: String,
    password: String,
    role: Option(Role),
  )
}

pub type UpdateMemberRequest {
  UpdateMemberRequest(
    membership_id: MembershipId,
    email_address: Option(String),
    legal_name: Option(String),
    date_of_birth: Option(String),
    handle: Option(String),
    postal_address: Option(String),
    phone_number: Option(String),
    password: Option(String),
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

// Database interaction functions

pub fn create(
  _conn: pog.Connection,
  _request: CreateMemberRequest,
) -> Result(MemberRecord, String) {
  Error("Not implemented yet")
}

pub fn get(
  _conn: pog.Connection,
  _membership_id: MembershipId,
) -> Result(MemberRecord, String) {
  Error("Not implemented yet")
}

pub fn list(_conn: pog.Connection) -> Result(List(MemberRecord), String) {
  Error("Not implemented yet")
}

pub fn update(
  _conn: pog.Connection,
  _request: UpdateMemberRequest,
) -> Result(MemberRecord, String) {
  Error("Not implemented yet")
}

pub fn delete(
  _conn: pog.Connection,
  _membership_id: MembershipId,
  _purge_pii: Bool,
) -> Result(Nil, String) {
  Error("Not implemented yet")
}

pub fn to_json(member: MemberRecord) -> json.Json {
  json.object([
    #("membership_num", json.int(member.membership_num)),
    #(
      "membership_id",
      json.string(membership_id.to_string(member.membership_id)),
    ),
    #("email_address", json.string(member.email_address)),
    #("legal_name", json.string(member.legal_name)),
    #("date_of_birth", json.string(member.date_of_birth)),
    #("handle", json.string(member.handle)),
    #("postal_address", json.string(member.postal_address)),
    #("phone_number", json.string(member.phone_number)),
    #("role", json.string(role.to_string(member.role))),
    #("created_at", json.string(birl.to_iso8601(member.created_at))),
    #("updated_at", json.string(birl.to_iso8601(member.updated_at))),
    #("deleted_at", case member.deleted_at {
      option.Some(time) -> json.string(birl.to_iso8601(time))
      option.None -> json.null()
    }),
  ])
}

fn decode_errors_to_string(errors: List(decode.DecodeError)) -> String {
  errors
  |> list.map(fn(error) {
    let decode.DecodeError(expected, found, path) = error
    "Problem with field "
    <> string.join(path, ".")
    <> " (expected "
    <> expected
    <> ", found "
    <> found
    <> ")"
  })
  |> string.join(". ")
}

pub fn decode_create_member_request(
  data: Dynamic,
) -> Result(CreateMemberRequest, String) {
  let decoder = {
    use email_address <- decode.field("email_address", decode.string)
    use legal_name <- decode.field("legal_name", decode.string)
    use date_of_birth <- decode.field("date_of_birth", decode.string)
    use handle <- decode.field("handle", decode.string)
    use postal_address <- decode.field("postal_address", decode.string)
    use phone_number <- decode.field("phone_number", decode.string)
    use password <- decode.field("password", decode.string)
    use role_str <- decode.field("role", decode.string)
    let role = case role.from_string(role_str) {
      Ok(role) -> option.Some(role)
      Error(_) -> option.None
    }

    decode.success(CreateMemberRequest(
      email_address: email_address,
      legal_name: legal_name,
      date_of_birth: date_of_birth,
      handle: handle,
      postal_address: postal_address,
      phone_number: phone_number,
      password: password,
      role: role,
    ))
  }
  decode.run(data, decoder)
  |> result.map_error(decode_errors_to_string)
}
