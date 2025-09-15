import config
import gleam/string
import models/membership_id
import models/role
import router
import test_helpers.{
  cleanup_test_member, create_test_member_with_details, setup_test_db,
}
import wisp/testing

pub fn member_cannot_list_all_members_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "member@example.com"
  let conf = config.load()

  // Clean up and create member user
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(member) =
    create_test_member_with_details(
      conn,
      test_email,
      "password",
      "Member User",
      "member",
      role.Member,
    )

  // Test GET /admin/members with member session
  let req =
    testing.get("/admin/members", [])
    |> test_helpers.set_session_cookie(member)

  let response = router.handle_request(req, conf, conn)

  // Should return 403 Forbidden
  let assert 403 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "not authorised")

  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn regstaff_can_list_all_members_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "regstaff@example.com"
  let conf = config.load()

  // Clean up and create regstaff user
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(regstaff) =
    create_test_member_with_details(
      conn,
      test_email,
      "password",
      "RegStaff User",
      "regstaff",
      role.RegStaff,
    )

  // Test GET /admin/members with regstaff session
  let req =
    testing.get("/admin/members", [])
    |> test_helpers.set_session_cookie(regstaff)

  let response = router.handle_request(req, conf, conn)

  // Should return 200 OK
  let assert 200 = response.status

  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn member_can_access_own_details_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "owndetails@example.com"
  let conf = config.load()

  // Clean up and create member user
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(member) =
    create_test_member_with_details(
      conn,
      test_email,
      "password",
      "Own Details User",
      "owndetails",
      role.Member,
    )

  // Test GET /admin/members/{own_id} with member session
  let member_id_str = membership_id.to_string(member.membership_id)
  let req =
    testing.get("/admin/members/" <> member_id_str, [])
    |> test_helpers.set_session_cookie(member)

  let response = router.handle_request(req, conf, conn)

  // Should return 200 OK
  let assert 200 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, member_id_str)

  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn member_cannot_access_others_details_test() {
  let assert Ok(conn) = setup_test_db()
  let member_email = "member@example.com"
  let other_email = "other@example.com"
  let conf = config.load()

  // Clean up and create both users
  let _ = cleanup_test_member(conn, member_email)
  let _ = cleanup_test_member(conn, other_email)
  let assert Ok(member) =
    create_test_member_with_details(
      conn,
      member_email,
      "password",
      "Member User",
      "member",
      role.Member,
    )
  let assert Ok(other) =
    create_test_member_with_details(
      conn,
      other_email,
      "password",
      "Other User",
      "other",
      role.Member,
    )

  // Test GET /admin/members/{other_id} with member session
  let other_id_str = membership_id.to_string(other.membership_id)
  let req =
    testing.get("/admin/members/" <> other_id_str, [])
    |> test_helpers.set_session_cookie(member)

  let response = router.handle_request(req, conf, conn)

  // Should return 403 Forbidden
  let assert 403 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "not authorised")

  // Cleanup
  let _ = cleanup_test_member(conn, member_email)
  let _ = cleanup_test_member(conn, other_email)
}

pub fn regstaff_can_access_others_details_test() {
  let assert Ok(conn) = setup_test_db()
  let regstaff_email = "regstaff@example.com"
  let member_email = "member@example.com"
  let conf = config.load()

  // Clean up and create both users
  let _ = cleanup_test_member(conn, regstaff_email)
  let _ = cleanup_test_member(conn, member_email)
  let assert Ok(regstaff) =
    create_test_member_with_details(
      conn,
      regstaff_email,
      "password",
      "RegStaff User",
      "regstaff",
      role.RegStaff,
    )
  let assert Ok(member) =
    create_test_member_with_details(
      conn,
      member_email,
      "password",
      "Member User",
      "member",
      role.Member,
    )

  // Test GET /admin/members/{member_id} with regstaff session
  let member_id_str = membership_id.to_string(member.membership_id)
  let req =
    testing.get("/admin/members/" <> member_id_str, [])
    |> test_helpers.set_session_cookie(regstaff)

  let response = router.handle_request(req, conf, conn)

  // Should return 200 OK
  let assert 200 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, member_id_str)

  // Cleanup
  let _ = cleanup_test_member(conn, regstaff_email)
  let _ = cleanup_test_member(conn, member_email)
}
