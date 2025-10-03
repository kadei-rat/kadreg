// Integration tests for member database operations
// These tests require a running PostgreSQL database
import errors
import gleam/int
import gleam/list
import gleam/option
import models/members
import models/members_db
import models/membership_id
import models/role
import test_helpers.{cleanup_test_member, setup_test_db}

pub fn create_member_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "test_create@example.com"

  // Clean up any existing test data
  let _ = cleanup_test_member(db_coord, test_email)

  let request =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Test User",
      date_of_birth: "1990-01-01",
      handle: "testuser",
      postal_address: "123 Test St",
      phone_number: "555-0123",
      password: "testpassword123",
      role: option.Some(role.Member),
    )

  // Test creation
  let assert Ok(created_member) = members_db.create(db_coord, request)

  // Verify the created member
  let assert True = created_member.membership_num > 0
  let assert True = created_member.email_address == test_email
  let assert "Test User" = created_member.legal_name
  let assert "testuser" = created_member.handle
  let assert role.Member = created_member.role

  // Verify membership ID generation
  let expected_membership_id =
    membership_id.from_number(created_member.membership_num)
  let assert True =
    membership_id.to_string(created_member.membership_id)
    == membership_id.to_string(expected_membership_id)

  // Test authentication with correct password
  let assert Ok(authenticated_member) =
    members_db.authenticate(db_coord, test_email, "testpassword123")
  let assert True =
    authenticated_member.membership_num == created_member.membership_num
  let assert True =
    authenticated_member.email_address == created_member.email_address

  // Test authentication with wrong password
  let assert Error(errors.AuthenticationError(msg)) =
    members_db.authenticate(db_coord, test_email, "wrongpassword")
  let assert True = msg == "Invalid password"

  // Clean up
  let _ = cleanup_test_member(db_coord, test_email)
}

pub fn get_member_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "test_get@example.com"

  // Clean up any existing test data
  let _ = cleanup_test_member(db_coord, test_email)

  let request =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Get Test User",
      date_of_birth: "1985-05-15",
      handle: "gettest",
      postal_address: "456 Get Ave",
      phone_number: "555-0456",
      password: "getpassword123",
      role: option.Some(role.Staff),
    )

  // Create a member first
  let assert Ok(created_member) = members_db.create(db_coord, request)

  // Test get by membership ID
  let assert Ok(retrieved_member) =
    members_db.get(db_coord, created_member.membership_id)

  // Verify retrieved member matches created member
  let assert True =
    retrieved_member.membership_num == created_member.membership_num
  let assert True =
    retrieved_member.email_address == created_member.email_address
  let assert True = retrieved_member.legal_name == created_member.legal_name
  let assert True = retrieved_member.handle == created_member.handle
  let assert True = retrieved_member.role == created_member.role

  // Test get with invalid membership ID
  let invalid_id = membership_id.from_number(999)
  let assert Error(errors.NotFoundError(msg)) =
    members_db.get(db_coord, invalid_id)
  let assert True = msg == "Member not found"

  // Clean up
  let _ = cleanup_test_member(db_coord, test_email)
}

pub fn list_members_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_emails = [
    "list1@example.com",
    "list2@example.com",
    "list3@example.com",
  ]

  // Clean up any existing test data
  test_emails
  |> list.each(fn(email) {
    let _ = cleanup_test_member(db_coord, email)
  })

  // Create multiple test members
  let requests = [
    members.CreateMemberRequest(
      email_address: "list1@example.com",
      legal_name: "List User 1",
      date_of_birth: "1990-01-01",
      handle: "listuser1",
      postal_address: "123 List St",
      phone_number: "555-0001",
      password: "password1",
      role: option.Some(role.Member),
    ),
    members.CreateMemberRequest(
      email_address: "list2@example.com",
      legal_name: "List User 2",
      date_of_birth: "1991-02-02",
      handle: "listuser2",
      postal_address: "456 List Ave",
      phone_number: "555-0002",
      password: "password2",
      role: option.Some(role.Staff),
    ),
    members.CreateMemberRequest(
      email_address: "list3@example.com",
      legal_name: "List User 3",
      date_of_birth: "1992-03-03",
      handle: "listuser3",
      postal_address: "789 List Blvd",
      phone_number: "555-0003",
      password: "password3",
      role: option.Some(role.Director),
    ),
  ]

  let created_members =
    requests
    |> list.map(fn(req) {
      let assert Ok(member) = members_db.create(db_coord, req)
      member
    })

  // Test list function
  let assert Ok(all_members) = members_db.list(db_coord)

  // Verify our test members are in the list
  created_members
  |> list.each(fn(created) {
    let found =
      all_members
      |> list.any(fn(listed) { listed.email_address == created.email_address })
    let assert True = found
  })

  // Verify list is ordered by membership_num
  let membership_nums =
    all_members
    |> list.map(fn(m) { m.membership_num })

  let sorted_nums =
    membership_nums
    |> list.sort(int.compare)

  let assert True = membership_nums == sorted_nums

  // Clean up
  test_emails
  |> list.each(fn(email) {
    let _ = cleanup_test_member(db_coord, email)
  })
}

pub fn duplicate_constraints_test() {
  let assert Ok(db_coord) = setup_test_db()
  let test_email = "duplicate@example.com"
  let test_handle = "duplicatehandle"

  // Clean up any existing test data
  let _ = cleanup_test_member(db_coord, test_email)

  let request1 =
    members.CreateMemberRequest(
      email_address: test_email,
      legal_name: "Duplicate Test 1",
      date_of_birth: "1990-01-01",
      handle: test_handle,
      postal_address: "123 Dup St",
      phone_number: "555-0111",
      password: "dup1pass",
      role: option.Some(role.Member),
    )

  // Create first member
  let assert Ok(_) = members_db.create(db_coord, request1)

  // Try to create second member with same email (should fail)
  let request2 =
    members.CreateMemberRequest(
      email_address: test_email,
      // Same email
      legal_name: "Duplicate Test 2",
      date_of_birth: "1991-01-01",
      handle: "differenthandle",
      // Different handle
      postal_address: "456 Dup Ave",
      phone_number: "555-0222",
      password: "dup2pass",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(_, _)) =
    members_db.create(db_coord, request2)

  // Try to create third member with same handle (should fail)
  let request3 =
    members.CreateMemberRequest(
      email_address: "different@example.com",
      // Different email
      legal_name: "Duplicate Test 3",
      date_of_birth: "1992-01-01",
      handle: test_handle,
      // Same handle
      postal_address: "789 Dup Blvd",
      phone_number: "555-0333",
      password: "dup3pass",
      role: option.Some(role.RegStaff),
    )

  let assert Error(errors.ValidationError(_, _)) =
    members_db.create(db_coord, request3)

  // Clean up
  let _ = cleanup_test_member(db_coord, test_email)
}
