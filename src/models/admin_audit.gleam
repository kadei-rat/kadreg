pub type AdminActionType {
  UpdateMember
  DeleteMember
}

pub fn action_type_to_string(action: AdminActionType) -> String {
  case action {
    UpdateMember -> "update_member"
    DeleteMember -> "delete_member"
  }
}

pub fn action_type_from_string(s: String) -> Result(AdminActionType, Nil) {
  case s {
    "update_member" -> Ok(UpdateMember)
    "delete_member" -> Ok(DeleteMember)
    _ -> Error(Nil)
  }
}

pub type AuditLogEntry {
  AuditLogEntry(
    audit_id: Int,
    performed_by: Int,
    action_type: AdminActionType,
    target_member: Int,
    old_values: String,
    new_values: String,
    performed_at: String,
  )
}
