import errors.{type AppError}
import gleam/option.{type Option}

pub type RegistrationTier {
  Standard
  Sponsor
  Subsidised
  DoubleSubsidised
}

pub type RegistrationStatus {
  Pending
  Successful
  Paid
  Cancelled
}

pub type Registration {
  Registration(
    member_id: Int,
    convention_id: String,
    tier: RegistrationTier,
    status: RegistrationStatus,
    created_at: String,
    updated_at: String,
  )
}

pub type RegistrationWithMember {
  RegistrationWithMember(
    member_id: Int,
    first_name: String,
    username: Option(String),
    convention_id: String,
    tier: RegistrationTier,
    status: RegistrationStatus,
    created_at: String,
    updated_at: String,
  )
}

pub fn tier_to_string(tier: RegistrationTier) -> String {
  case tier {
    Standard -> "standard"
    Sponsor -> "sponsor"
    Subsidised -> "subsidised"
    DoubleSubsidised -> "double_subsidised"
  }
}

pub fn tier_to_display_string(tier: RegistrationTier) -> String {
  case tier {
    Standard -> "Standard"
    Sponsor -> "Sponsor"
    Subsidised -> "Subsidised"
    DoubleSubsidised -> "Double Subsidised"
  }
}

pub fn tier_from_string(str: String) -> Result(RegistrationTier, AppError) {
  case str {
    "standard" -> Ok(Standard)
    "sponsor" -> Ok(Sponsor)
    "subsidised" -> Ok(Subsidised)
    "double_subsidised" -> Ok(DoubleSubsidised)
    _ ->
      Error(errors.validation_error(
        "Invalid registration tier: " <> str,
        "Registration tier parsing failed for: " <> str,
      ))
  }
}

pub fn status_to_string(status: RegistrationStatus) -> String {
  case status {
    Pending -> "pending"
    Successful -> "successful"
    Paid -> "paid"
    Cancelled -> "cancelled"
  }
}

pub fn status_to_display_string(status: RegistrationStatus) -> String {
  case status {
    Pending -> "Pending"
    Successful -> "Successful"
    Paid -> "Paid"
    Cancelled -> "Cancelled"
  }
}

pub fn status_from_string(str: String) -> Result(RegistrationStatus, AppError) {
  case str {
    "pending" -> Ok(Pending)
    "successful" -> Ok(Successful)
    "paid" -> Ok(Paid)
    "cancelled" -> Ok(Cancelled)
    _ ->
      Error(errors.validation_error(
        "Invalid registration status: " <> str,
        "Registration status parsing failed for: " <> str,
      ))
  }
}

pub fn can_user_modify(status: RegistrationStatus) -> Bool {
  case status {
    Pending | Successful -> True
    Paid | Cancelled -> False
  }
}
