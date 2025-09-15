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

// Check if user can access member details
pub fn check_manage_member_details(
  session_data: SessionData,
  desired_membership_id: MembershipId,
) -> Result(Nil, AppError) {
  case
    role_level(session_data.role) >= role_level(role.RegStaff)
    || session_data.membership_id == desired_membership_id
  {
    True -> Ok(Nil)
    False ->
      Error(errors.authorization_error(
        "User is not authorised to manage this member's details",
      ))
  }
}

pub fn check_manage_members(session_data: SessionData) -> Result(Nil, AppError) {
  case role_level(session_data.role) >= role_level(role.RegStaff) {
    True -> Ok(Nil)
    False ->
      Error(errors.authorization_error(
        "User is not authorised to list all members",
      ))
  }
}

pub fn can_access_admin(session_data: SessionData) -> Bool {
  role_level(session_data.role) >= role_level(role.Staff)
}

pub fn check_access_admin(session_data: SessionData) -> Result(Nil, AppError) {
  case can_access_admin(session_data) {
    True -> Ok(Nil)
    False ->
      Error(errors.authorization_error("User is not authorised to access admin"))
  }
}
