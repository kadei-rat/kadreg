import errors.{type AppError}
import models/membership_id.{type MembershipId}
import models/role.{type Role}
import session.{type SessionData}

// Role hierarchy levels (higher number = more permissions)
pub fn role_level(role: Role) -> Int {
  case role {
    role.Member -> 1
    role.Staff -> 2
    role.RegStaff -> 3
    role.Director -> 4
    role.Sysadmin -> 5
  }
}

// Check if a role has admin-level permissions (RegStaff or higher)
pub fn can_manage_members(role: Role) -> Bool {
  role_level(role) >= role_level(role.RegStaff)
}

// Check if user can access member details
pub fn can_manage_member_details(
  session_data: SessionData,
  desired_membership_id: MembershipId,
) -> Result(Nil, AppError) {
  case
    can_manage_members(session_data.role)
    || session_data.membership_id == desired_membership_id
  {
    True -> Ok(Nil)
    False ->
      Error(errors.authorization_error(
        "User is not authorised to manage this member's details",
      ))
  }
}

pub fn can_list_members(session_data: SessionData) -> Result(Nil, AppError) {
  case can_manage_members(session_data.role) {
    True -> Ok(Nil)
    False ->
      Error(errors.authorization_error(
        "User is not authorised to list all members",
      ))
  }
}

pub fn can_create_members(session_data: SessionData) -> Result(Nil, AppError) {
  case can_manage_members(session_data.role) {
    True -> Ok(Nil)
    False ->
      Error(errors.authorization_error(
        "User is not authorised to create new members",
      ))
  }
}
