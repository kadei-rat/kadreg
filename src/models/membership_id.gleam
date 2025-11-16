import errors.{type AppError}
import gleam/int
import gleam/result
import gleam/string

pub type MembershipId {
  MembershipId(String)
}

const prefix = "KAD"

const total_length = 7

const number_length = 4

// Generate a membership ID from a membership number
// Example: 34 -> "KAD0034"
pub fn from_number(membership_num: Int) -> MembershipId {
  let padded_number =
    int.to_string(membership_num)
    |> string.pad_start(number_length, "0")

  let full_id = prefix <> padded_number
  MembershipId(full_id)
}

// Extract the membership number from a membership ID
// Example: "KAD0034" -> 34
pub fn to_number(membership_id: MembershipId) -> Result(Int, AppError) {
  let MembershipId(id_str) = membership_id

  validate_length(id_str)
  |> result.try(validate_prefix)
  |> result.try(parse_number_part)
}

pub fn to_string(id: MembershipId) -> String {
  case id {
    MembershipId(str) -> str
  }
}

fn validate_length(id_str: String) -> Result(String, AppError) {
  case string.length(id_str) == total_length {
    True -> Ok(id_str)
    False ->
      Error(errors.validation_error(
        "Invalid membership ID length: expected "
          <> int.to_string(total_length)
          <> " characters",
        "Length validation failed for: " <> id_str,
      ))
  }
}

fn validate_prefix(id_str: String) -> Result(String, AppError) {
  let actual_prefix = string.slice(id_str, 0, 3)
  case actual_prefix == prefix {
    True -> Ok(id_str)
    False ->
      Error(errors.validation_error(
        "Invalid membership ID prefix: expected '" <> prefix <> "'",
        "Prefix validation failed for: " <> id_str,
      ))
  }
}

fn parse_number_part(id_str: String) -> Result(Int, AppError) {
  let number_part = string.slice(id_str, 3, number_length)
  case int.parse(number_part) {
    Ok(num) -> Ok(num)
    Error(_) ->
      Error(errors.validation_error(
        "Invalid membership ID number part: '" <> number_part <> "'",
        "Number parsing failed for: " <> id_str,
      ))
  }
}

pub fn is_valid(membership_id: MembershipId) -> Bool {
  case to_number(membership_id) {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn parse(id_str: String) -> Result(MembershipId, AppError) {
  use _ <- result.try(validate_length(id_str))
  use _ <- result.try(validate_prefix(id_str))
  use _ <- result.try(parse_number_part(id_str))
  Ok(MembershipId(id_str))
}
