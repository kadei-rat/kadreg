import argus
import errors.{type AppError}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/string
import models/membership_id.{type MembershipId}
import models/role.{type Role}
import pog
import utils

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

// Database interaction functions

pub fn hash_password(password: String) -> Result(String, AppError) {
  case argus.hasher() |> argus.hash(password, argus.gen_salt()) {
    Ok(hashes) -> Ok(hashes.encoded_hash)
    Error(err) -> Error(errors.internal_error("Password hashing failed: " <> string.inspect(err)))
  }
}

pub fn verify_password(encoded_hash: String, password: String) -> Bool {
  case argus.verify(encoded_hash, password) {
    Ok(True) -> True
    _ -> False
  }
}

pub fn create(
  conn: pog.Connection,
  request: CreateMemberRequest,
) -> Result(MemberRecord, AppError) {
  // Default role to Member if not specified
  let role = case request.role {
    option.Some(role) -> role
    option.None -> role.Member
  }

  use password_hash <- result.try(hash_password(request.password))

  let sql =
    "
    INSERT INTO members (
      email_address, legal_name, date_of_birth, handle, 
      postal_address, phone_number, password_hash, role
    ) 
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING membership_num, email_address, legal_name, date_of_birth,
              handle, postal_address, phone_number, password_hash, role,
              created_at::text, updated_at::text, deleted_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(request.email_address))
    |> pog.parameter(pog.text(request.legal_name))
    |> pog.parameter(pog.text(request.date_of_birth))
    |> pog.parameter(pog.text(request.handle))
    |> pog.parameter(pog.text(request.postal_address))
    |> pog.parameter(pog.text(request.phone_number))
    |> pog.parameter(pog.text(password_hash))
    |> pog.parameter(pog.text(role.to_string(role)))
    |> pog.returning(decode_member_from_db())
    |> pog.execute(conn)
    |> result.map_error(fn(err) { errors.internal_error("Database error: " <> string.inspect(err)) }),
  )

  case rows.rows {
    [member] -> Ok(member)
    [] -> Error(errors.internal_error("Insert failed - no rows returned"))
    _ -> Error(errors.internal_error("Insert returned multiple rows (unexpected)"))
  }
}

pub fn get(
  conn: pog.Connection,
  membership_id: MembershipId,
) -> Result(MemberRecord, AppError) {
  // Convert membership ID to number for database query
  use membership_num <- result.try(membership_id.to_number(membership_id))

  let sql =
    "
    SELECT membership_num, email_address, legal_name, date_of_birth,
           handle, postal_address, phone_number, password_hash, role,
           created_at::text, updated_at::text, deleted_at::text
    FROM members
    WHERE membership_num = $1 AND deleted_at IS NULL
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(membership_num))
    |> pog.returning(decode_member_from_db())
    |> pog.execute(conn)
    |> result.map_error(fn(err) { errors.internal_error("Database error: " <> string.inspect(err)) }),
  )

  case rows.rows {
    [member] -> Ok(member)
    [] -> Error(errors.not_found_error("Member not found"))
    _ -> Error(errors.internal_error("Multiple members found (unexpected)"))
  }
}

pub fn list(conn: pog.Connection) -> Result(List(MemberRecord), AppError) {
  let sql =
    "
    SELECT membership_num, email_address, legal_name, date_of_birth,
           handle, postal_address, phone_number, password_hash, role,
           created_at::text, updated_at::text, deleted_at::text
    FROM members 
    WHERE deleted_at IS NULL
    ORDER BY membership_num ASC
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.returning(decode_member_from_db())
    |> pog.execute(conn)
    |> result.map_error(fn(err) { errors.internal_error("Database error: " <> string.inspect(err)) }),
  )

  Ok(rows.rows)
}

pub fn authenticate(
  conn: pog.Connection,
  email_address: String,
  password: String,
) -> Result(MemberRecord, AppError) {
  let sql =
    "
    SELECT membership_num, email_address, legal_name, date_of_birth,
           handle, postal_address, phone_number, password_hash, role,
           created_at::text, updated_at::text, deleted_at::text
    FROM members
    WHERE email_address = $1 AND deleted_at IS NULL
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(email_address))
    |> pog.returning(decode_member_from_db())
    |> pog.execute(conn)
    |> result.map_error(fn(err) { errors.internal_error("Database error: " <> string.inspect(err)) }),
  )

  case rows.rows {
    [member] -> {
      case verify_password(member.password_hash, password) {
        True -> Ok(member)
        False -> Error(errors.authentication_error("Invalid password"))
      }
    }
    [] -> Error(errors.authentication_error("Member not found"))
    _ -> Error(errors.internal_error("Multiple members found (unexpected)"))
  }
}

pub fn delete(
  _conn: pog.Connection,
  _membership_id: MembershipId,
  _purge_pii: Bool,
) -> Result(Nil, AppError) {
  Error(errors.internal_error("Not implemented yet"))
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
    #("created_at", json.string(member.created_at)),
    #("updated_at", json.string(member.updated_at)),
    #("deleted_at", case member.deleted_at {
      option.Some(time_str) -> json.string(time_str)
      option.None -> json.null()
    }),
  ])
}

fn decode_member_from_db() -> decode.Decoder(MemberRecord) {
  {
    use membership_num <- decode.field("membership_num", decode.int)
    use email_address <- decode.field("email_address", decode.string)
    use legal_name <- decode.field("legal_name", decode.string)
    use date_of_birth <- decode.field("date_of_birth", decode.string)
    use handle <- decode.field("handle", decode.string)
    use postal_address <- decode.field("postal_address", decode.string)
    use phone_number <- decode.field("phone_number", decode.string)
    use password_hash <- decode.field("password_hash", decode.string)
    use role_str <- decode.field("role", decode.string)
    use created_at <- decode.field("created_at", decode.string)
    use updated_at <- decode.field("updated_at", decode.string)
    use deleted_at <- decode.optional_field(
      "deleted_at",
      option.None,
      decode.optional(decode.string),
    )

    // Parse role - if invalid, default to Member
    let role = case role.from_string(role_str) {
      Ok(role) -> role
      Error(_) -> role.Member
    }

    decode.success(MemberRecord(
      membership_num: membership_num,
      membership_id: membership_id.from_number(membership_num),
      email_address: email_address,
      legal_name: legal_name,
      date_of_birth: date_of_birth,
      handle: handle,
      postal_address: postal_address,
      phone_number: phone_number,
      password_hash: password_hash,
      role: role,
      created_at: created_at,
      updated_at: updated_at,
      deleted_at: deleted_at,
    ))
  }
}

pub fn decode_create_member_request(
  data: Dynamic,
) -> Result(CreateMemberRequest, AppError) {
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
  |> result.map_error(fn(err) { errors.validation_error(utils.decode_errors_to_string(err)) })
}
