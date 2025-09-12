import errors
import gleam/dynamic/decode
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

pub fn decode_create_member_request_test() {
  let json_data =
    json.object([
      #("email_address", json.string("test@example.com")),
      #("legal_name", json.string("John Smith")),
      #("date_of_birth", json.string("1985-03-10")),
      #("handle", json.string("johnsmith")),
      #("postal_address", json.string("456 Oak Ave")),
      #("phone_number", json.string("555-5678")),
      #("password", json.string("secret123")),
      #("role", json.string("Staff")),
    ])

  let assert Ok(dynamic_data) =
    json.parse(json.to_string(json_data), decode.dynamic)
  let assert Ok(request) = members.decode_create_member_request(dynamic_data)

  let assert "test@example.com" = request.email_address
  let assert "John Smith" = request.legal_name
  let assert "1985-03-10" = request.date_of_birth
  let assert "johnsmith" = request.handle
  let assert "456 Oak Ave" = request.postal_address
  let assert "555-5678" = request.phone_number
  let assert "secret123" = request.password
  let assert option.Some(role.Staff) = request.role
}

pub fn decode_create_member_request_with_default_member_role_test() {
  let json_data =
    json.object([
      #("email_address", json.string("test@example.com")),
      #("legal_name", json.string("John Smith")),
      #("date_of_birth", json.string("1985-03-10")),
      #("handle", json.string("johnsmith")),
      #("postal_address", json.string("456 Oak Ave")),
      #("phone_number", json.string("555-5678")),
      #("password", json.string("secret123")),
      #("role", json.string("Member")),
    ])

  let assert Ok(dynamic_data) =
    json.parse(json.to_string(json_data), decode.dynamic)
  let assert Ok(request) = members.decode_create_member_request(dynamic_data)

  let assert option.Some(role.Member) = request.role
}

pub fn decode_create_member_request_missing_field_test() {
  let json_data =
    json.object([
      #("email_address", json.string("test@example.com")),
      // Missing legal_name
      #("date_of_birth", json.string("1985-03-10")),
      #("handle", json.string("johnsmith")),
      #("postal_address", json.string("456 Oak Ave")),
      #("phone_number", json.string("555-5678")),
      #("password", json.string("secret123")),
      #("role", json.string("Member")),
    ])

  let assert Ok(dynamic_data) =
    json.parse(json.to_string(json_data), decode.dynamic)
  let assert Error(errors.ValidationError(msg)) = members.decode_create_member_request(dynamic_data)
  let assert True = string.contains(msg, "legal_name")
}

pub fn decode_create_member_request_invalid_role_test() {
  let json_data =
    json.object([
      #("email_address", json.string("test@example.com")),
      #("legal_name", json.string("John Smith")),
      #("date_of_birth", json.string("1985-03-10")),
      #("handle", json.string("johnsmith")),
      #("postal_address", json.string("456 Oak Ave")),
      #("phone_number", json.string("555-5678")),
      #("password", json.string("secret123")),
      #("role", json.string("InvalidRole")),
    ])

  let assert Ok(dynamic_data) =
    json.parse(json.to_string(json_data), decode.dynamic)
  let assert Ok(request) = members.decode_create_member_request(dynamic_data)
  let assert option.None = request.role
}
