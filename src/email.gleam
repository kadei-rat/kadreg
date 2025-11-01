import gleam/io
import gleam/uri

pub fn send_email_confirmation_email(
  base_url: String,
  email_address: String,
  token: String,
) -> Nil {
  let confirmation_url =
    base_url
    <> "/auth/confirm_email?email="
    <> uri.percent_encode(email_address)
    <> "&token="
    <> token

  io.println("")
  io.println("========================================")
  io.println("EMAIL CONFIRMATION")
  io.println("========================================")
  io.println("To: " <> email_address)
  io.println("")
  io.println("Please confirm your email address by clicking the link below:")
  io.println("")
  io.println(confirmation_url)
  io.println("")
  io.println("========================================")
  io.println("")
}
