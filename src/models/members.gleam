import argus
import database
import errors.{type AppError}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
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

// Database interaction functions

pub fn hash_password(password: String) -> Result(String, AppError) {
  case argus.hasher() |> argus.hash(password, argus.gen_salt()) {
    Ok(hashes) -> Ok(hashes.encoded_hash)
    Error(err) ->
      Error(errors.internal_error(
        "Password hashing failed",
        "Password hashing failed: " <> string.inspect(err),
      ))
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
    |> result.map_error(database.to_app_error),
  )

  case rows.rows {
    [member] -> Ok(member)
    [] ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Insert failed - no rows returned",
      ))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Insert returned multiple rows (unexpected)",
      ))
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
    |> result.map_error(database.to_app_error),
  )

  case rows.rows {
    [member] -> Ok(member)
    [] -> Error(errors.not_found_error("Member not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple members found (unexpected)",
      ))
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
    |> result.map_error(database.to_app_error),
  )

  Ok(rows.rows)
}

pub type MemberStats {
  MemberStats(
    total_members: Int,
    recent_signups: Int,
    total_staff: Int,
    total_deleted: Int,
  )
}

pub fn get_stats(conn: pog.Connection) -> Result(MemberStats, AppError) {
  let total_sql =
    "SELECT COUNT(*) as count FROM members WHERE deleted_at IS NULL"
  let recent_sql =
    "SELECT COUNT(*) as count FROM members WHERE deleted_at IS NULL AND created_at > NOW() - INTERVAL '30 days'"
  let staff_sql =
    "SELECT COUNT(*) as count FROM members WHERE deleted_at IS NULL AND role IN ('Staff', 'RegStaff', 'Director', 'Sysadmin')"
  let deleted_sql =
    "SELECT COUNT(*) as count FROM members WHERE deleted_at IS NOT NULL"

  let count_decoder = {
    use count <- decode.field("count", decode.int)
    decode.success(count)
  }

  use total_rows <- result.try(
    pog.query(total_sql)
    |> pog.returning(count_decoder)
    |> pog.execute(conn)
    |> result.map_error(database.to_app_error),
  )

  use recent_rows <- result.try(
    pog.query(recent_sql)
    |> pog.returning(count_decoder)
    |> pog.execute(conn)
    |> result.map_error(database.to_app_error),
  )

  use staff_rows <- result.try(
    pog.query(staff_sql)
    |> pog.returning(count_decoder)
    |> pog.execute(conn)
    |> result.map_error(database.to_app_error),
  )

  use deleted_rows <- result.try(
    pog.query(deleted_sql)
    |> pog.returning(count_decoder)
    |> pog.execute(conn)
    |> result.map_error(database.to_app_error),
  )

  let total_members = case total_rows.rows {
    [count] -> count
    _ -> 0
  }

  let recent_signups = case recent_rows.rows {
    [count] -> count
    _ -> 0
  }

  let total_staff = case staff_rows.rows {
    [count] -> count
    _ -> 0
  }

  let total_deleted = case deleted_rows.rows {
    [count] -> count
    _ -> 0
  }

  Ok(MemberStats(
    total_members: total_members,
    recent_signups: recent_signups,
    total_staff: total_staff,
    total_deleted: total_deleted,
  ))
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
    |> result.map_error(database.to_app_error),
  )

  case rows.rows {
    [member] -> {
      case verify_password(member.password_hash, password) {
        True -> Ok(member)
        False -> Error(errors.authentication_error("Invalid password"))
      }
    }
    [] -> Error(errors.authentication_error("Member not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple members found (unexpected)",
      ))
  }
}

pub fn update_profile(
  conn: pog.Connection,
  membership_id: MembershipId,
  request: UpdateMemberRequest,
) -> Result(MemberRecord, AppError) {
  // Convert membership ID to number for database query
  use membership_num <- result.try(membership_id.to_number(membership_id))

  // First verify current password
  use current_member <- result.try(get(conn, membership_id))
  case verify_password(current_member.password_hash, request.current_password) {
    False -> Error(errors.authentication_error("Current password is incorrect"))
    True -> {
      // Handle password update if provided
      let password_hash = case request.new_password {
        Some(new_pass) -> {
          use new_hash <- result.try(hash_password(new_pass))
          Ok(new_hash)
        }
        None -> Ok(current_member.password_hash)
      }

      use final_password_hash <- result.try(password_hash)

      let sql =
        "
        UPDATE members
        SET email_address = $1, legal_name = $2, handle = $3, postal_address = $4,
        phone_number = $5, password_hash = $6, updated_at = NOW()
        WHERE membership_num = $7 AND deleted_at IS NULL
        RETURNING membership_num, email_address, legal_name,
                  handle, postal_address, phone_number, password_hash, role,
                  created_at::text, updated_at::text, deleted_at::text
      "

      use rows <- result.try(
        pog.query(sql)
        |> pog.parameter(pog.text(request.email_address))
        |> pog.parameter(pog.text(request.legal_name))
        |> pog.parameter(pog.text(request.handle))
        |> pog.parameter(pog.text(request.postal_address))
        |> pog.parameter(pog.text(request.phone_number))
        |> pog.parameter(pog.text(final_password_hash))
        |> pog.parameter(pog.int(membership_num))
        |> pog.returning(decode_member_from_db())
        |> pog.execute(conn)
        |> result.map_error(database.to_app_error),
      )

      case rows.rows {
        [member] -> Ok(member)
        [] ->
          Error(errors.not_found_error("Member not found or already deleted"))
        _ ->
          Error(errors.internal_error(
            errors.public_5xx_msg,
            "Update returned multiple rows (unexpected)",
          ))
      }
    }
  }
}

pub fn admin_update(
  conn: pog.Connection,
  membership_id: MembershipId,
  request: AdminUpdateMemberRequest,
) -> Result(MemberRecord, AppError) {
  // Convert membership ID to number for database query
  use membership_num <- result.try(membership_id.to_number(membership_id))

  let sql =
    "
    UPDATE members
    SET email_address = $1, legal_name = $2, date_of_birth = $3, handle = $4,
        postal_address = $5, phone_number = $6, role = $7, updated_at = NOW()
    WHERE membership_num = $8 AND deleted_at IS NULL
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
    |> pog.parameter(pog.text(role.to_string(request.role)))
    |> pog.parameter(pog.int(membership_num))
    |> pog.returning(decode_member_from_db())
    |> pog.execute(conn)
    |> result.map_error(database.to_app_error),
  )

  case rows.rows {
    [member] -> Ok(member)
    [] -> Error(errors.not_found_error("Member not found or already deleted"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Update returned multiple rows (unexpected)",
      ))
  }
}

pub fn delete(
  conn: pog.Connection,
  membership_id: MembershipId,
  purge_pii: Bool,
) -> Result(Nil, AppError) {
  use membership_num <- result.try(membership_id.to_number(membership_id))

  let sql = case purge_pii {
    True ->
      "
      UPDATE members
      SET legal_name = '(deleted)', handle = '(deleted)',
          postal_address = '(deleted)', phone_number = '(deleted)',
          deleted_at = NOW()
      WHERE membership_num = $1 AND deleted_at IS NULL
    "
    False ->
      "
      UPDATE members
      SET deleted_at = NOW()
      WHERE membership_num = $1 AND deleted_at IS NULL
    "
  }

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(membership_num))
    |> pog.execute(conn)
    |> result.map_error(database.to_app_error),
  )

  case rows.count {
    1 -> Ok(Nil)
    0 -> Error(errors.not_found_error("Member not found or already deleted"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Delete affected multiple rows (unexpected)",
      ))
  }
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
