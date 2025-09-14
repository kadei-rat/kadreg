import errors
import gleam/json
import gleam/option
import gleam/string
import models/members
import models/membership_id
import models/role

pub fn encode_member_test() {
  let member =
    members.MemberRecord(
      membership_num: 42,
      membership_id: membership_id.from_number(42),
      email_address: "test@example.com",
      legal_name: "Jane Doe",
      date_of_birth: "1990-01-15",
      handle: "janedoe",
      postal_address: "123 Main St",
      phone_number: "555-1234",
      password_hash: "hashed_password",
      role: role.Member,
      created_at: "2021-12-31T20:00:00Z",
      updated_at: "2021-12-31T20:00:00Z",
      deleted_at: option.None,
    )

  let encoded = members.to_json(member)
  let encoded_str = json.to_string(encoded)

  let assert True = string.contains(encoded_str, "\"membership_num\":42")
  let assert True =
    string.contains(encoded_str, "\"membership_id\":\"PAW0042\"")
  let assert True =
    string.contains(encoded_str, "\"email_address\":\"test@example.com\"")
  let assert True = string.contains(encoded_str, "\"legal_name\":\"Jane Doe\"")
  let assert True = string.contains(encoded_str, "\"role\":\"Member\"")
  let assert True = string.contains(encoded_str, "\"deleted_at\":null")
  // Ensure password_hash is NOT included in JSON
  let assert False = string.contains(encoded_str, "password_hash")
}

pub fn validate_member_request_valid_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "test@example.com",
      legal_name: "John Smith",
      date_of_birth: "1985-03-10",
      handle: "johnsmith",
      postal_address: "456 Oak Ave",
      phone_number: "555-5678",
      password: "secretpassword123",
      role: option.Some(role.Staff),
    )

  let assert Ok(validated_request) = members.validate_member_request(request)
  let assert "test@example.com" = validated_request.email_address
  let assert "John Smith" = validated_request.legal_name
  let assert "secretpassword123" = validated_request.password
}

pub fn validate_member_request_invalid_email_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "invalid-email",
      legal_name: "John Smith",
      date_of_birth: "1985-03-10",
      handle: "johnsmith",
      postal_address: "456 Oak Ave",
      phone_number: "555-5678",
      password: "secretpassword123",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    members.validate_member_request(request)
  let assert True = string.contains(msg, "Invalid email address")
}

pub fn validate_member_request_empty_legal_name_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "test@example.com",
      legal_name: "",
      date_of_birth: "1985-03-10",
      handle: "johnsmith",
      postal_address: "456 Oak Ave",
      phone_number: "555-5678",
      password: "secretpassword123",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    members.validate_member_request(request)
  let assert True = string.contains(msg, "Must specify a legal name")
}

pub fn validate_member_request_empty_phone_number_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "test@example.com",
      legal_name: "John Smith",
      date_of_birth: "1985-03-10",
      handle: "johnsmith",
      postal_address: "456 Oak Ave",
      phone_number: "",
      password: "secretpassword123",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    members.validate_member_request(request)
  let assert True = string.contains(msg, "Must specify a phone number")
}

pub fn validate_member_request_empty_handle_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "test@example.com",
      legal_name: "John Smith",
      date_of_birth: "1985-03-10",
      handle: "",
      postal_address: "456 Oak Ave",
      phone_number: "555-5678",
      password: "secretpassword123",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    members.validate_member_request(request)
  let assert True = string.contains(msg, "Must specify a handle")
}

pub fn validate_member_request_empty_postal_address_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "test@example.com",
      legal_name: "John Smith",
      date_of_birth: "1985-03-10",
      handle: "johnsmith",
      postal_address: "",
      phone_number: "555-5678",
      password: "secretpassword123",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    members.validate_member_request(request)
  let assert True = string.contains(msg, "Must specify a postal address")
}

pub fn validate_member_request_empty_date_of_birth_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "test@example.com",
      legal_name: "John Smith",
      date_of_birth: "",
      handle: "johnsmith",
      postal_address: "456 Oak Ave",
      phone_number: "555-5678",
      password: "secretpassword123",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    members.validate_member_request(request)
  let assert True = string.contains(msg, "Must specify a date of birth")
}

pub fn validate_member_request_short_password_test() {
  let request =
    members.CreateMemberRequest(
      email_address: "test@example.com",
      legal_name: "John Smith",
      date_of_birth: "1985-03-10",
      handle: "johnsmith",
      postal_address: "456 Oak Ave",
      phone_number: "555-5678",
      password: "short",
      role: option.Some(role.Staff),
    )

  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    members.validate_member_request(request)
  let assert True = string.contains(msg, "Password must be at least 12 characters")
}