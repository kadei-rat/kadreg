import argus
import db_coordinator.{type DbCoordName}
import errors.{type AppError}
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/option
import gleam/result
import gleam/string
import models/members
import models/membership_id
import models/pending_members
import models/role
import pog

pub fn create(
  db: DbCoordName,
  request: members.CreateMemberRequest,
) -> Result(pending_members.PendingMemberRecord, AppError) {
  let sql =
    "
    INSERT INTO pending_members (
    email_address, legal_name, date_of_birth, handle,
    postal_address, phone_number, password_hash, email_confirm_token
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING email_address, legal_name, date_of_birth, handle,
    postal_address, phone_number, password_hash, email_confirm_token,
    created_at::text
    "

  use password_hash <- result.try(hash_password(request.password))
  let email_confirm_token = generate_token()

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(request.email_address))
    |> pog.parameter(pog.text(request.legal_name))
    |> pog.parameter(pog.text(request.date_of_birth))
    |> pog.parameter(pog.text(request.handle))
    |> pog.parameter(pog.text(request.postal_address))
    |> pog.parameter(pog.text(request.phone_number))
    |> pog.parameter(pog.text(password_hash))
    |> pog.parameter(pog.text(email_confirm_token))
    |> pog.returning(decode_pending_member_from_db())
    |> db_coordinator.pending_member_query(db),
  )

  case rows.rows {
    [pending_member] -> Ok(pending_member)
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

pub fn confirm_and_convert_to_member(
  db: DbCoordName,
  email: String,
  token: String,
) -> Result(members.MemberRecord, AppError) {
  // verify the pending member exists and token matches
  let sql_verify =
    "
    SELECT email_address, legal_name, date_of_birth, handle,
           postal_address, phone_number, password_hash, email_confirm_token,
           created_at::text
    FROM pending_members
    WHERE email_address = $1 AND email_confirm_token = $2
  "

  use verify_rows <- result.try(
    pog.query(sql_verify)
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(token))
    |> pog.returning(decode_pending_member_from_db())
    |> db_coordinator.pending_member_query(db),
  )

  case verify_rows.rows {
    [] ->
      Error(errors.validation_error(
        "Invalid email or confirmation token",
        "Invalid email or confirmation token",
      ))
    [pending_member] -> {
      // Create the full member
      let sql_create_member =
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

      use create_rows <- result.try(
        pog.query(sql_create_member)
        |> pog.parameter(pog.text(pending_member.email_address))
        |> pog.parameter(pog.text(pending_member.legal_name))
        |> pog.parameter(pog.text(pending_member.date_of_birth))
        |> pog.parameter(pog.text(pending_member.handle))
        |> pog.parameter(pog.text(pending_member.postal_address))
        |> pog.parameter(pog.text(pending_member.phone_number))
        |> pog.parameter(pog.text(pending_member.password_hash))
        |> pog.parameter(pog.text(role.to_string(role.Member)))
        |> pog.returning(decode_member_from_db())
        |> db_coordinator.member_query(db),
      )

      case create_rows.rows {
        [member] -> {
          // Delete the pending member
          let sql_delete =
            "
            DELETE FROM pending_members
            WHERE email_address = $1
          "

          use _ <- result.try(
            pog.query(sql_delete)
            |> pog.parameter(pog.text(email))
            |> db_coordinator.noresult_query(db),
          )

          Ok(member)
        }
        [] ->
          Error(errors.internal_error(
            errors.public_5xx_msg,
            "Member creation failed - no rows returned",
          ))
        _ ->
          Error(errors.internal_error(
            errors.public_5xx_msg,
            "Member creation returned multiple rows (unexpected)",
          ))
      }
    }
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple pending members found (unexpected)",
      ))
  }
}

// used by tests
pub fn get(
  db: db_coordinator.DbCoordName,
  email: String,
) -> Result(pending_members.PendingMemberRecord, errors.AppError) {
  let sql =
    "
    SELECT email_address, legal_name, date_of_birth, handle,
           postal_address, phone_number, password_hash, email_confirm_token,
           created_at::text
    FROM pending_members
    WHERE email_address = $1
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(email))
    |> pog.returning(decode_pending_member_from_db())
    |> db_coordinator.pending_member_query(db),
  )

  case rows.rows {
    [pending_member] -> Ok(pending_member)
    [] -> Error(errors.not_found_error("Pending member not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple pending members found (unexpected)",
      ))
  }
}

fn decode_pending_member_from_db() -> decode.Decoder(
  pending_members.PendingMemberRecord,
) {
  {
    use email_address <- decode.field("email_address", decode.string)
    use legal_name <- decode.field("legal_name", decode.string)
    use date_of_birth <- decode.field("date_of_birth", decode.string)
    use handle <- decode.field("handle", decode.string)
    use postal_address <- decode.field("postal_address", decode.string)
    use phone_number <- decode.field("phone_number", decode.string)
    use password_hash <- decode.field("password_hash", decode.string)
    use email_confirm_token <- decode.field(
      "email_confirm_token",
      decode.string,
    )
    use created_at <- decode.field("created_at", decode.string)

    decode.success(pending_members.PendingMemberRecord(
      email_address: email_address,
      legal_name: legal_name,
      date_of_birth: date_of_birth,
      handle: handle,
      postal_address: postal_address,
      phone_number: phone_number,
      password_hash: password_hash,
      email_confirm_token: email_confirm_token,
      created_at: created_at,
    ))
  }
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

fn generate_token() -> String {
  crypto.strong_random_bytes(32)
  |> bit_array.base16_encode
  |> string.lowercase
}
