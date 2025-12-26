import db_coordinator.{type DbCoordName}
import errors.{type AppError}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import models/admin_audit
import models/admin_audit_db
import models/members.{type MemberStats, MemberStats}
import models/role
import pog

pub type TelegramAuthData {
  TelegramAuthData(
    telegram_id: Int,
    first_name: String,
    username: Option(String),
  )
}

/// Get or create a member from Telegram auth data.
/// If the member exists, update their first_name and username (in case they changed).
/// If not, create a new member.
pub fn upsert_from_telegram(
  db: DbCoordName,
  auth_data: TelegramAuthData,
) -> Result(members.MemberRecord, AppError) {
  let sql =
    "
    INSERT INTO members (telegram_id, first_name, username)
    VALUES ($1, $2, $3)
    ON CONFLICT (telegram_id) DO UPDATE
    SET first_name = EXCLUDED.first_name,
        username = EXCLUDED.username,
        updated_at = NOW()
    WHERE members.deleted_at IS NULL
    RETURNING telegram_id, first_name, username, emergency_contact,
              role, created_at::text, updated_at::text, deleted_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(auth_data.telegram_id))
    |> pog.parameter(pog.text(auth_data.first_name))
    |> pog.parameter(case auth_data.username {
      Some(u) -> pog.text(u)
      None -> pog.null()
    })
    |> pog.returning(decode_member_from_db())
    |> db_coordinator.member_query(db),
  )

  case rows.rows {
    [member] -> Ok(member)
    [] -> Error(errors.authentication_error("Account has been deleted"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Upsert returned multiple rows (unexpected)",
      ))
  }
}

pub fn get(
  db: DbCoordName,
  telegram_id: Int,
) -> Result(members.MemberRecord, AppError) {
  let sql =
    "
    SELECT telegram_id, first_name, username, emergency_contact,
           role, created_at::text, updated_at::text, deleted_at::text
    FROM members
    WHERE telegram_id = $1 AND deleted_at IS NULL
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(telegram_id))
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
    SELECT telegram_id, first_name, username, emergency_contact,
           role, created_at::text, updated_at::text, deleted_at::text
    FROM members
    WHERE deleted_at IS NULL
    ORDER BY created_at ASC
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

pub fn update_profile(
  db: DbCoordName,
  telegram_id: Int,
  request: members.UpdateMemberRequest,
) -> Result(members.MemberRecord, AppError) {
  let sql =
    "
    UPDATE members
    SET emergency_contact = $1, updated_at = NOW()
    WHERE telegram_id = $2 AND deleted_at IS NULL
    RETURNING telegram_id, first_name, username, emergency_contact,
              role, created_at::text, updated_at::text, deleted_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(case request.emergency_contact {
      Some(contact) -> pog.text(contact)
      None -> pog.null()
    })
    |> pog.parameter(pog.int(telegram_id))
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

pub fn admin_update(
  db: DbCoordName,
  performed_by: Int,
  target_telegram_id: Int,
  request: members.AdminUpdateMemberRequest,
) -> Result(members.MemberRecord, AppError) {
  use old_member <- result.try(get(db, target_telegram_id))

  let sql =
    "
    UPDATE members
    SET first_name = $1, username = $2, emergency_contact = $3, role = $4, updated_at = NOW()
    WHERE telegram_id = $5 AND deleted_at IS NULL
    RETURNING telegram_id, first_name, username, emergency_contact,
              role, created_at::text, updated_at::text, deleted_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(request.first_name))
    |> pog.parameter(case request.username {
      Some(u) -> pog.text(u)
      None -> pog.null()
    })
    |> pog.parameter(case request.emergency_contact {
      Some(contact) -> pog.text(contact)
      None -> pog.null()
    })
    |> pog.parameter(pog.text(role.to_string(request.role)))
    |> pog.parameter(pog.int(target_telegram_id))
    |> pog.returning(decode_member_from_db())
    |> db_coordinator.member_query(db),
  )

  case rows.rows {
    [member] -> {
      let old_values = members.member_to_json(old_member)
      let new_values = members.member_to_json(member)

      let _ =
        admin_audit_db.log_admin_action(
          db,
          performed_by,
          admin_audit.UpdateMember,
          target_telegram_id,
          old_values,
          new_values,
        )

      Ok(member)
    }
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
  telegram_id: Int,
  purge_pii: Bool,
) -> Result(Nil, AppError) {
  let sql = case purge_pii {
    True ->
      "
      UPDATE members
      SET first_name = '(deleted)', username = NULL, deleted_at = NOW()
      WHERE telegram_id = $1 AND deleted_at IS NULL
    "
    False ->
      "
      UPDATE members
      SET deleted_at = NOW()
      WHERE telegram_id = $1 AND deleted_at IS NULL
    "
  }

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(telegram_id))
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
    #("telegram_id", json.int(member.telegram_id)),
    #("first_name", json.string(member.first_name)),
    #("username", case member.username {
      Some(u) -> json.string(u)
      None -> json.null()
    }),
    #("role", json.string(role.to_string(member.role))),
    #("created_at", json.string(member.created_at)),
    #("updated_at", json.string(member.updated_at)),
    #("deleted_at", case member.deleted_at {
      Some(time_str) -> json.string(time_str)
      None -> json.null()
    }),
  ])
}

fn decode_member_from_db() -> decode.Decoder(members.MemberRecord) {
  use telegram_id <- decode.field("telegram_id", decode.int)
  use first_name <- decode.field("first_name", decode.string)
  use username <- decode.optional_field(
    "username",
    None,
    decode.optional(decode.string),
  )
  use emergency_contact <- decode.optional_field(
    "emergency_contact",
    None,
    decode.optional(decode.string),
  )
  use role_str <- decode.field("role", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use deleted_at <- decode.optional_field(
    "deleted_at",
    None,
    decode.optional(decode.string),
  )

  let role = case role.from_string(role_str) {
    Ok(role) -> role
    Error(_) -> role.Member
  }

  decode.success(members.MemberRecord(
    telegram_id: telegram_id,
    first_name: first_name,
    username: username,
    emergency_contact: emergency_contact,
    role: role,
    created_at: created_at,
    updated_at: updated_at,
    deleted_at: deleted_at,
  ))
}
