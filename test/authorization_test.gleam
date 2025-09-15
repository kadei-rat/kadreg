import authorization
import errors
import models/membership_id
import models/role
import session

// Test admin role detection
pub fn check_manage_members_test() {
  let member_id1 = membership_id.from_number(100)

  let member_session = session.SessionData(member_id1, role.Member)
  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_members(member_session)

  let staff_session = session.SessionData(member_id1, role.Staff)
  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_members(staff_session)

  let regstaff_session = session.SessionData(member_id1, role.RegStaff)
  let assert Ok(_) = authorization.check_manage_members(regstaff_session)

  let director_session = session.SessionData(member_id1, role.Director)
  let assert Ok(_) = authorization.check_manage_members(director_session)

  let sysadmin_session = session.SessionData(member_id1, role.Sysadmin)
  let assert Ok(_) = authorization.check_manage_members(sysadmin_session)
}

// Test member detail access permissions
pub fn check_manage_member_details_test() {
  let member_id1 = membership_id.from_number(100)
  let member_id2 = membership_id.from_number(200)

  // Members can access their own details
  let session_data = session.SessionData(member_id1, role.Member)
  let assert Ok(_) =
    authorization.check_manage_member_details(session_data, member_id1)

  // Members cannot access others' details
  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_member_details(session_data, member_id2)

  // Staff cannot access others' details (not admin level)
  let staff_session = session.SessionData(member_id1, role.Staff)
  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_member_details(staff_session, member_id2)

  // RegStaff can access anyone's details
  let regstaff_session = session.SessionData(member_id1, role.RegStaff)
  let assert Ok(_) =
    authorization.check_manage_member_details(regstaff_session, member_id2)

  // Director can access anyone's details
  let director_session = session.SessionData(member_id1, role.Director)
  let assert Ok(_) =
    authorization.check_manage_member_details(director_session, member_id2)

  // Sysadmin can access anyone's details
  let sysadmin_session = session.SessionData(member_id1, role.Sysadmin)
  let assert Ok(_) =
    authorization.check_manage_member_details(sysadmin_session, member_id2)
}
