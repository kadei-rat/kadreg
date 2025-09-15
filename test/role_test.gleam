import errors
import models/role

// Test role functionality
pub fn role_to_string_test() {
  let assert "Member" = role.to_string(role.Member)
  let assert "RegStaff" = role.to_string(role.RegStaff)
}

pub fn string_to_role_test() {
  let assert Ok(role.Member) = role.from_string("Member")
  let assert Error(errors.ValidationError(_, _)) = role.from_string("Invalid")
}
