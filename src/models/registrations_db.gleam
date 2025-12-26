import db_coordinator.{type DbCoordName}
import errors.{type AppError}
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import models/membership_id
import models/registrations.{
  type Registration, type RegistrationStatus, type RegistrationTier,
  type RegistrationWithMember, Registration, RegistrationWithMember,
}
import pog

pub fn get(
  db: DbCoordName,
  member_id: Int,
  convention_id: String,
) -> Result(Registration, AppError) {
  let sql =
    "
    SELECT member_id, convention_id, tier, status,
           created_at::text, updated_at::text
    FROM registrations
    WHERE member_id = $1 AND convention_id = $2
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(member_id))
    |> pog.parameter(pog.text(convention_id))
    |> pog.returning(decode_registration())
    |> db_coordinator.registration_query(db),
  )

  case rows.rows {
    [reg] -> Ok(reg)
    [] -> Error(errors.not_found_error("Registration not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple registrations found (unexpected)",
      ))
  }
}

pub fn list_for_convention(
  db: DbCoordName,
  convention_id: String,
) -> Result(List(Registration), AppError) {
  let sql =
    "
    SELECT member_id, convention_id, tier, status,
           created_at::text, updated_at::text
    FROM registrations
    WHERE convention_id = $1
    ORDER BY created_at DESC
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(convention_id))
    |> pog.returning(decode_registration())
    |> db_coordinator.registration_query(db),
  )

  Ok(rows.rows)
}

pub fn get_status_map_for_convention(
  db: DbCoordName,
  convention_id: String,
) -> Result(Dict(Int, RegistrationStatus), AppError) {
  list_for_convention(db, convention_id)
  |> result.map(fn(regs) {
    regs
    |> list.map(fn(reg) { #(reg.member_id, reg.status) })
    |> dict.from_list
  })
}

pub fn list_for_convention_with_members(
  db: DbCoordName,
  convention_id: String,
) -> Result(List(RegistrationWithMember), AppError) {
  let sql =
    "
    SELECT r.member_id, m.membership_num, m.handle, r.convention_id,
           r.tier, r.status, r.created_at::text, r.updated_at::text
    FROM registrations r
    JOIN members m ON r.member_id = m.membership_num
    WHERE r.convention_id = $1 AND m.deleted_at IS NULL
    ORDER BY r.created_at DESC
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(convention_id))
    |> pog.returning(decode_registration_with_member())
    |> db_coordinator.registration_with_member_query(db),
  )

  Ok(rows.rows)
}

pub fn get_with_member(
  db: DbCoordName,
  member_id: Int,
  convention_id: String,
) -> Result(RegistrationWithMember, AppError) {
  let sql =
    "
    SELECT r.member_id, m.membership_num, m.handle, r.convention_id,
           r.tier, r.status, r.created_at::text, r.updated_at::text
    FROM registrations r
    JOIN members m ON r.member_id = m.membership_num
    WHERE r.member_id = $1 AND r.convention_id = $2 AND m.deleted_at IS NULL
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(member_id))
    |> pog.parameter(pog.text(convention_id))
    |> pog.returning(decode_registration_with_member())
    |> db_coordinator.registration_with_member_query(db),
  )

  case rows.rows {
    [reg] -> Ok(reg)
    [] -> Error(errors.not_found_error("Registration not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple registrations found (unexpected)",
      ))
  }
}

pub fn create(
  db: DbCoordName,
  member_id: Int,
  convention_id: String,
  tier: RegistrationTier,
) -> Result(Registration, AppError) {
  let sql =
    "
    INSERT INTO registrations (member_id, convention_id, tier, status)
    VALUES ($1, $2, $3, 'pending')
    RETURNING member_id, convention_id, tier, status,
              created_at::text, updated_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(member_id))
    |> pog.parameter(pog.text(convention_id))
    |> pog.parameter(pog.text(registrations.tier_to_string(tier)))
    |> pog.returning(decode_registration())
    |> db_coordinator.registration_query(db),
  )

  case rows.rows {
    [reg] -> Ok(reg)
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

pub fn update_tier(
  db: DbCoordName,
  member_id: Int,
  convention_id: String,
  tier: RegistrationTier,
) -> Result(Registration, AppError) {
  let sql =
    "
    UPDATE registrations
    SET tier = $3, updated_at = NOW()
    WHERE member_id = $1 AND convention_id = $2
    RETURNING member_id, convention_id, tier, status,
              created_at::text, updated_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(member_id))
    |> pog.parameter(pog.text(convention_id))
    |> pog.parameter(pog.text(registrations.tier_to_string(tier)))
    |> pog.returning(decode_registration())
    |> db_coordinator.registration_query(db),
  )

  case rows.rows {
    [reg] -> Ok(reg)
    [] -> Error(errors.not_found_error("Registration not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Update returned multiple rows (unexpected)",
      ))
  }
}

pub fn update_status(
  db: DbCoordName,
  member_id: Int,
  convention_id: String,
  status: RegistrationStatus,
) -> Result(Registration, AppError) {
  let sql =
    "
    UPDATE registrations
    SET status = $3, updated_at = NOW()
    WHERE member_id = $1 AND convention_id = $2
    RETURNING member_id, convention_id, tier, status,
              created_at::text, updated_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(member_id))
    |> pog.parameter(pog.text(convention_id))
    |> pog.parameter(pog.text(registrations.status_to_string(status)))
    |> pog.returning(decode_registration())
    |> db_coordinator.registration_query(db),
  )

  case rows.rows {
    [reg] -> Ok(reg)
    [] -> Error(errors.not_found_error("Registration not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Update returned multiple rows (unexpected)",
      ))
  }
}

pub fn cancel(
  db: DbCoordName,
  member_id: Int,
  convention_id: String,
) -> Result(Registration, AppError) {
  update_status(db, member_id, convention_id, registrations.Cancelled)
}

pub fn admin_update(
  db: DbCoordName,
  member_id: Int,
  convention_id: String,
  tier: RegistrationTier,
  status: RegistrationStatus,
) -> Result(Registration, AppError) {
  let sql =
    "
    UPDATE registrations
    SET tier = $3, status = $4, updated_at = NOW()
    WHERE member_id = $1 AND convention_id = $2
    RETURNING member_id, convention_id, tier, status,
              created_at::text, updated_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(member_id))
    |> pog.parameter(pog.text(convention_id))
    |> pog.parameter(pog.text(registrations.tier_to_string(tier)))
    |> pog.parameter(pog.text(registrations.status_to_string(status)))
    |> pog.returning(decode_registration())
    |> db_coordinator.registration_query(db),
  )

  case rows.rows {
    [reg] -> Ok(reg)
    [] -> Error(errors.not_found_error("Registration not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Update returned multiple rows (unexpected)",
      ))
  }
}

fn decode_registration() -> decode.Decoder(Registration) {
  use member_id <- decode.field("member_id", decode.int)
  use convention_id <- decode.field("convention_id", decode.string)
  use tier_str <- decode.field("tier", decode.string)
  use status_str <- decode.field("status", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)

  let tier = case registrations.tier_from_string(tier_str) {
    Ok(t) -> t
    Error(_) -> registrations.Standard
  }

  let status = case registrations.status_from_string(status_str) {
    Ok(s) -> s
    Error(_) -> registrations.Pending
  }

  decode.success(Registration(
    member_id: member_id,
    convention_id: convention_id,
    tier: tier,
    status: status,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn decode_registration_with_member() -> decode.Decoder(RegistrationWithMember) {
  use member_id <- decode.field("member_id", decode.int)
  use membership_num <- decode.field("membership_num", decode.int)
  use handle <- decode.field("handle", decode.string)
  use convention_id <- decode.field("convention_id", decode.string)
  use tier_str <- decode.field("tier", decode.string)
  use status_str <- decode.field("status", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)

  let tier = case registrations.tier_from_string(tier_str) {
    Ok(t) -> t
    Error(_) -> registrations.Standard
  }

  let status = case registrations.status_from_string(status_str) {
    Ok(s) -> s
    Error(_) -> registrations.Pending
  }

  decode.success(RegistrationWithMember(
    member_id: member_id,
    membership_id: membership_id.from_number(membership_num),
    handle: handle,
    convention_id: convention_id,
    tier: tier,
    status: status,
    created_at: created_at,
    updated_at: updated_at,
  ))
}
