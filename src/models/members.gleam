import gleam/json
import gleam/option.{type Option}
import models/role.{type Role}

pub type MemberRecord {
  MemberRecord(
    telegram_id: Int,
    first_name: String,
    username: Option(String),
    emergency_contact: Option(String),
    role: Role,
    created_at: String,
    updated_at: String,
    deleted_at: Option(String),
  )
}

pub type UpdateMemberRequest {
  UpdateMemberRequest(emergency_contact: Option(String))
}

pub type AdminUpdateMemberRequest {
  AdminUpdateMemberRequest(
    first_name: String,
    username: Option(String),
    emergency_contact: Option(String),
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

pub fn member_to_json(member: MemberRecord) -> json.Json {
  json.object([
    #("telegram_id", json.int(member.telegram_id)),
    #("first_name", json.string(member.first_name)),
    #("username", case member.username {
      option.Some(u) -> json.string(u)
      option.None -> json.null()
    }),
    #("role", json.string(role.to_string(member.role))),
  ])
}
