import errors.{type AppError}

pub type Role {
  Member
  Staff
  RegStaff
  Director
  Sysadmin
}

pub fn to_string(role: Role) -> String {
  case role {
    Member -> "Member"
    Staff -> "Staff"
    RegStaff -> "RegStaff"
    Director -> "Director"
    Sysadmin -> "Sysadmin"
  }
}

pub fn from_string(str: String) -> Result(Role, AppError) {
  case str {
    "Member" -> Ok(Member)
    "Staff" -> Ok(Staff)
    "RegStaff" -> Ok(RegStaff)
    "Director" -> Ok(Director)
    "Sysadmin" -> Ok(Sysadmin)
    _ -> Error(errors.validation_error("Invalid role: " <> str))
  }
}
