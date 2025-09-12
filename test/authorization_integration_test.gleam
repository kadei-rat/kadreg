import gleam/json
import gleam/string
import models/membership_id
import models/role
import router
import test_helpers.{cleanup_test_member, create_test_member_with_details, setup_test_db}
import wisp/testing

pub fn member_cannot_list_all_members_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "member@example.com"
  
  // Clean up and create member user
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(member) = create_test_member_with_details(conn, test_email, "password", "Member User", "member", role.Member)
  
  // Test GET /members with member session
  let req = testing.get("/members", [])
    |> test_helpers.set_session_cookie(member)
  
  let response = router.handle_request(req, conn)
  
  // Should return 400 Forbidden
  let assert 400 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "not authorised")
  
  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn regstaff_can_list_all_members_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "regstaff@example.com"
  
  // Clean up and create regstaff user
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(regstaff) = create_test_member_with_details(conn, test_email, "password", "RegStaff User", "regstaff", role.RegStaff)
  
  // Test GET /members with regstaff session
  let req = testing.get("/members", [])
    |> test_helpers.set_session_cookie(regstaff)
  
  let response = router.handle_request(req, conn)
  
  // Should return 200 OK
  let assert 200 = response.status
  
  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn member_can_access_own_details_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "owndetails@example.com"
  
  // Clean up and create member user
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(member) = create_test_member_with_details(conn, test_email, "password", "Own Details User", "owndetails", role.Member)
  
  // Test GET /members/{own_id} with member session
  let member_id_str = membership_id.to_string(member.membership_id)
  let req = testing.get("/members/" <> member_id_str, [])
    |> test_helpers.set_session_cookie(member)
  
  let response = router.handle_request(req, conn)
  
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
  
  // Clean up and create both users
  let _ = cleanup_test_member(conn, member_email)
  let _ = cleanup_test_member(conn, other_email)
  let assert Ok(member) = create_test_member_with_details(conn, member_email, "password", "Member User", "member", role.Member)
  let assert Ok(other) = create_test_member_with_details(conn, other_email, "password", "Other User", "other", role.Member)
  
  // Test GET /members/{other_id} with member session
  let other_id_str = membership_id.to_string(other.membership_id)
  let req = testing.get("/members/" <> other_id_str, [])
    |> test_helpers.set_session_cookie(member)
  
  let response = router.handle_request(req, conn)
  
  // Should return 400 Forbidden
  let assert 400 = response.status
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
  
  // Clean up and create both users
  let _ = cleanup_test_member(conn, regstaff_email)
  let _ = cleanup_test_member(conn, member_email)
  let assert Ok(regstaff) = create_test_member_with_details(conn, regstaff_email, "password", "RegStaff User", "regstaff", role.RegStaff)
  let assert Ok(member) = create_test_member_with_details(conn, member_email, "password", "Member User", "member", role.Member)
  
  // Test GET /members/{member_id} with regstaff session
  let member_id_str = membership_id.to_string(member.membership_id)
  let req = testing.get("/members/" <> member_id_str, [])
    |> test_helpers.set_session_cookie(regstaff)
  
  let response = router.handle_request(req, conn)
  
  // Should return 200 OK
  let assert 200 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, member_id_str)
  
  // Cleanup
  let _ = cleanup_test_member(conn, regstaff_email)
  let _ = cleanup_test_member(conn, member_email)
}

pub fn member_cannot_create_members_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "member@example.com"
  
  // Clean up and create member user
  let _ = cleanup_test_member(conn, test_email)
  let assert Ok(member) = create_test_member_with_details(conn, test_email, "password", "Member User", "member", role.Member)
  
  // Test POST /members with member session
  let create_json = json.object([
    #("email_address", json.string("newmember@example.com")),
    #("legal_name", json.string("New Member")),
    #("date_of_birth", json.string("1990-01-01")),
    #("handle", json.string("newmember")),
    #("postal_address", json.string("123 New St")),
    #("phone_number", json.string("555-0001")),
    #("password", json.string("password")),
    #("role", json.string("Member")),
  ])
  
  let req = testing.post_json("/members", [], create_json)
    |> test_helpers.set_session_cookie(member)
  
  let response = router.handle_request(req, conn)
  
  // Should return 400 Forbidden
  let assert 400 = response.status
  let body = testing.string_body(response)
  let assert True = string.contains(body, "not authorised")
  
  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
}

pub fn regstaff_can_create_members_test() {
  let assert Ok(conn) = setup_test_db()
  let test_email = "regstaff@example.com"
  let new_member_email = "newmember@example.com"
  
  // Clean up and create regstaff user
  let _ = cleanup_test_member(conn, test_email)
  let _ = cleanup_test_member(conn, new_member_email)
  let assert Ok(regstaff) = create_test_member_with_details(conn, test_email, "password", "RegStaff User", "regstaff", role.RegStaff)
  
  // Test POST /members with regstaff session
  let create_json = json.object([
    #("email_address", json.string(new_member_email)),
    #("legal_name", json.string("New Member")),
    #("date_of_birth", json.string("1990-01-01")),
    #("handle", json.string("newmember")),
    #("postal_address", json.string("123 New St")),
    #("phone_number", json.string("555-0001")),
    #("password", json.string("password")),
    #("role", json.string("Member")),
  ])
  
  let req = testing.post_json("/members", [], create_json)
    |> test_helpers.set_session_cookie(regstaff)
  
  let response = router.handle_request(req, conn)
  
  // Should return 201 Created
  let assert 201 = response.status
  
  // Cleanup
  let _ = cleanup_test_member(conn, test_email)
  let _ = cleanup_test_member(conn, new_member_email)
}