import errors
import gleam/string
import models/membership_id

// Test membership ID generation
pub fn membership_id_from_number_test() {
  let membership_id = membership_id.from_number(34)
  let assert Ok(34) = membership_id.to_number(membership_id)
}

pub fn membership_id_format_test() {
  let membership_id = membership_id.from_number(34)
  let assert "PAW0034" = membership_id.to_string(membership_id)
}

pub fn membership_id_parse_valid_test() {
  let assert Ok(_) = membership_id.parse("PAW0034")
}

pub fn membership_id_parse_invalid_test() {
  let assert Error(_) = membership_id.parse("INVALID")
}

// Test to_number function with valid inputs
pub fn membership_id_to_number_valid_test() {
  let id = membership_id.from_number(123)
  let assert Ok(123) = membership_id.to_number(id)
}

pub fn membership_id_to_number_zero_test() {
  let id = membership_id.from_number(0)
  let assert Ok(0) = membership_id.to_number(id)
}

pub fn membership_id_to_number_max_test() {
  let id = membership_id.from_number(9999)
  let assert Ok(9999) = membership_id.to_number(id)
}

// Test to_number function with invalid length
pub fn membership_id_to_number_too_short_test() {
  let invalid_id = membership_id.MembershipId("PAW12")
  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    membership_id.to_number(invalid_id)
  let assert True = string.contains(msg, "Invalid membership ID length")
}

pub fn membership_id_to_number_too_long_test() {
  let invalid_id = membership_id.MembershipId("PAW00123456")
  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    membership_id.to_number(invalid_id)
  let assert True = string.contains(msg, "Invalid membership ID length")
}

// Test to_number function with invalid prefix
pub fn membership_id_to_number_wrong_prefix_test() {
  let invalid_id = membership_id.MembershipId("XYZ0034")
  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    membership_id.to_number(invalid_id)
  let assert True = string.contains(msg, "Invalid membership ID prefix")
}

pub fn membership_id_to_number_lowercase_prefix_test() {
  let invalid_id = membership_id.MembershipId("paw0034")
  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    membership_id.to_number(invalid_id)
  let assert True = string.contains(msg, "Invalid membership ID prefix")
}

// Test to_number function with invalid number part
pub fn membership_id_to_number_non_numeric_test() {
  let invalid_id = membership_id.MembershipId("PAWABCD")
  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    membership_id.to_number(invalid_id)
  let assert True = string.contains(msg, "Invalid membership ID number part")
}

pub fn membership_id_to_number_mixed_chars_test() {
  let invalid_id = membership_id.MembershipId("PAW12AB")
  let assert Error(errors.ValidationError(public: msg, internal: _)) =
    membership_id.to_number(invalid_id)
  let assert True = string.contains(msg, "Invalid membership ID number part")
}
