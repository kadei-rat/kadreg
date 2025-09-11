import gleam/int
import gleam/result
import gleam/string

pub type MembershipId {
  MembershipId(String)
}

const prefix = "PAW"

const total_length = 7

const number_length = 4

// Generate a membership ID from a membership number
// Example: 34 -> "PAW0034"
pub fn from_number(membership_num: Int) -> MembershipId {
  let padded_number =
    int.to_string(membership_num)
    |> string.pad_start(number_length, "0")

  let full_id = prefix <> padded_number
  MembershipId(full_id)
}

// Extract the membership number from a membership ID
// Example: "PAW0034" -> 34
pub fn to_number(membership_id: MembershipId) -> Result(Int, String) {
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

fn validate_length(id_str: String) -> Result(String, String) {
  case string.length(id_str) == total_length {
    True -> Ok(id_str)
    False ->
      Error(
        "Invalid membership ID length: expected "
        <> int.to_string(total_length)
        <> " characters",
      )
  }
}

fn validate_prefix(id_str: String) -> Result(String, String) {
  let actual_prefix = string.slice(id_str, 0, 3)
  case actual_prefix == prefix {
    True -> Ok(id_str)
    False -> Error("Invalid membership ID prefix: expected '" <> prefix <> "'")
  }
}

fn parse_number_part(id_str: String) -> Result(Int, String) {
  let number_part = string.slice(id_str, 3, number_length)
  case int.parse(number_part) {
    Ok(num) -> Ok(num)
    Error(_) ->
      Error("Invalid membership ID number part: '" <> number_part <> "'")
  }
}

pub fn is_valid(membership_id: MembershipId) -> Bool {
  case to_number(membership_id) {
    Ok(_) -> True
    Error(_) -> False
  }
}

pub fn parse(id_str: String) -> Result(MembershipId, String) {
  let candidate_id = MembershipId(id_str)
  case is_valid(candidate_id) {
    True -> Ok(candidate_id)
    False -> Error("Invalid membership ID format: '" <> id_str <> "'")
  }
}
