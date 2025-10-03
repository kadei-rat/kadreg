import db_coordinator.{type DbCoordName}
import errors.{type AppError}
import gleam/dynamic/decode
import gleam/json
import gleam/result
import models/admin_audit.{type AuditLogEntry, AuditLogEntry}
import models/membership_id.{type MembershipId}
import pog

pub fn log_admin_action(
  db: DbCoordName,
  performed_by: MembershipId,
  action_type: admin_audit.AdminActionType,
  target_member: MembershipId,
  old_values: json.Json,
  new_values: json.Json,
) -> Result(Nil, AppError) {
  use performed_by_num <- result.try(membership_id.to_number(performed_by))
  use target_member_num <- result.try(membership_id.to_number(target_member))

  let sql =
    "
    INSERT INTO admin_audit_log (
      performed_by, action_type, target_member, old_values, new_values
    )
    VALUES ($1, $2, $3, $4, $5)
  "

  use _rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(performed_by_num))
    |> pog.parameter(pog.text(admin_audit.action_type_to_string(action_type)))
    |> pog.parameter(pog.int(target_member_num))
    |> pog.parameter(pog.text(json.to_string(old_values)))
    |> pog.parameter(pog.text(json.to_string(new_values)))
    |> db_coordinator.noresult_query(db),
  )

  Ok(Nil)
}

pub fn get_actions(db: DbCoordName) -> Result(List(AuditLogEntry), AppError) {
  let sql =
    "
    SELECT audit_id, performed_by, action_type, target_member,
           old_values::text, new_values::text, performed_at::text
    FROM admin_audit_log
    ORDER BY performed_at DESC
  "

  let decoder = {
    use audit_id <- decode.field("audit_id", decode.int)
    use performed_by_num <- decode.field("performed_by", decode.int)
    use action_type_str <- decode.field("action_type", decode.string)
    use target_member_num <- decode.field("target_member", decode.int)
    use old_values <- decode.field("old_values", decode.string)
    use new_values <- decode.field("new_values", decode.string)
    use performed_at <- decode.field("performed_at", decode.string)

    let action_type = case
      admin_audit.action_type_from_string(action_type_str)
    {
      Ok(action) -> action
      Error(_) -> admin_audit.UpdateMember
    }

    decode.success(AuditLogEntry(
      audit_id: audit_id,
      performed_by: membership_id.from_number(performed_by_num),
      action_type: action_type,
      target_member: membership_id.from_number(target_member_num),
      old_values: old_values,
      new_values: new_values,
      performed_at: performed_at,
    ))
  }

  use rows <- result.try(
    pog.query(sql)
    |> pog.returning(decoder)
    |> db_coordinator.audit_query(db),
  )

  Ok(rows.rows)
}
