import argus
import db_coordinator.{type DbCoordName}
import errors.{type AppError}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import models/members.{type MemberStats, MemberStats}
import models/membership_id.{type MembershipId}
import models/role
import pog

pub fn create(
  db: DbCoordName,
  request: members.CreateMemberRequest,
) -> Result(members.MemberRecord, AppError) {
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
    |> db_coordinator.member_query(db),
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
  db: DbCoordName,
  membership_id: MembershipId,
) -> Result(members.MemberRecord, AppError) {
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
    |> db_coordinator.member_query(db),
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

pub fn list(db: DbCoordName) -> Result(List(members.MemberRecord), AppError) {
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
    |> db_coordinator.member_query(db),
  )

  Ok(rows.rows)
}

pub fn get_stats(db: DbCoordName) -> Result(MemberStats, AppError) {
  let sql =
    "
    SELECT
    COUNT(*) FILTER (WHERE deleted_at IS NULL) as total,
    COUNT(*) FILTER (WHERE deleted_at IS NULL AND created_at > NOW() - INTERVAL '30 days') as recent,
    COUNT(*) FILTER (WHERE deleted_at IS NULL AND role IN ('Staff', 'RegStaff', 'Director', 'Sysadmin')) as staff,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as deleted
    FROM members
    "

  let stats_decoder = {
    use total_members <- decode.field("total", decode.int)
    use recent_signups <- decode.field("recent", decode.int)
    use total_staff <- decode.field("staff", decode.int)
    use total_deleted <- decode.field("deleted", decode.int)

    decode.success(MemberStats(
      total_members: total_members,
      recent_signups: recent_signups,
      total_staff: total_staff,
      total_deleted: total_deleted,
    ))
  }

  pog.query(sql)
  |> pog.returning(stats_decoder)
  |> db_coordinator.stats_query(db)
  |> result.try(fn(res) {
    case res.rows {
      [s] -> Ok(s)
      _ ->
        Error(errors.internal_error(
          errors.public_5xx_msg,
          "Unable to parse stats db response",
        ))
    }
  })
}

pub fn authenticate(
  db: DbCoordName,
  email_address: String,
  password: String,
) -> Result(members.MemberRecord, AppError) {
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
    |> db_coordinator.member_query(db),
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
  db: DbCoordName,
  membership_id: MembershipId,
  request: members.UpdateMemberRequest,
) -> Result(members.MemberRecord, AppError) {
  // Convert membership ID to number for database query
  use membership_num <- result.try(membership_id.to_number(membership_id))

  // First verify current password
  use current_member <- result.try(get(db, membership_id))
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
        |> db_coordinator.member_query(db),
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
  db: DbCoordName,
  membership_id: MembershipId,
  request: members.AdminUpdateMemberRequest,
) -> Result(members.MemberRecord, AppError) {
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
    |> db_coordinator.member_query(db),
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
  db: DbCoordName,
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
    |> db_coordinator.noresult_query(db),
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

pub fn to_json(member: members.MemberRecord) -> json.Json {
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

fn decode_member_from_db() -> decode.Decoder(members.MemberRecord) {
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

    decode.success(members.MemberRecord(
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

fn hash_password(password: String) -> Result(String, AppError) {
  case argus.hasher() |> argus.hash(password, argus.gen_salt()) {
    Ok(hashes) -> Ok(hashes.encoded_hash)
    Error(err) ->
      Error(errors.internal_error(
        "Password hashing failed",
        "Password hashing failed: " <> string.inspect(err),
      ))
  }
}

fn verify_password(encoded_hash: String, password: String) -> Bool {
  case argus.verify(encoded_hash, password) {
    Ok(True) -> True
    _ -> False
  }
}
