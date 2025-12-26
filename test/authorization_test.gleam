import authorization
import errors
import models/role
import session

pub fn check_manage_members_test() {
  let telegram_id1 = 100

  let member_session = session.SessionData(telegram_id1, role.Member)
  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_members(member_session)

  let staff_session = session.SessionData(telegram_id1, role.Staff)
  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_members(staff_session)

  let regstaff_session = session.SessionData(telegram_id1, role.RegStaff)
  let assert Ok(_) = authorization.check_manage_members(regstaff_session)

  let director_session = session.SessionData(telegram_id1, role.Director)
  let assert Ok(_) = authorization.check_manage_members(director_session)

  let sysadmin_session = session.SessionData(telegram_id1, role.Sysadmin)
  let assert Ok(_) = authorization.check_manage_members(sysadmin_session)
}

pub fn check_manage_member_details_test() {
  let telegram_id1 = 100
  let telegram_id2 = 200

  let session_data = session.SessionData(telegram_id1, role.Member)
  let assert Ok(_) =
    authorization.check_manage_member_details(session_data, telegram_id1)

  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_member_details(session_data, telegram_id2)

  let staff_session = session.SessionData(telegram_id1, role.Staff)
  let assert Error(errors.AuthorizationError(_)) =
    authorization.check_manage_member_details(staff_session, telegram_id2)

  let regstaff_session = session.SessionData(telegram_id1, role.RegStaff)
  let assert Ok(_) =
    authorization.check_manage_member_details(regstaff_session, telegram_id2)

  let director_session = session.SessionData(telegram_id1, role.Director)
  let assert Ok(_) =
    authorization.check_manage_member_details(director_session, telegram_id2)

  let sysadmin_session = session.SessionData(telegram_id1, role.Sysadmin)
  let assert Ok(_) =
    authorization.check_manage_member_details(sysadmin_session, telegram_id2)
}
