import config.{type EmailConfig, EmailConfig, NoEmail}
import gleam/hackney
import gleam/io
import gleam/uri
import logging
import zeptomail.{Addressee, TextBody}

pub fn send_email_confirmation_email(
  email_config: EmailConfig,
  con_name: String,
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

  let subject = con_name <> " - Please confirm your email address"
  let body = "hi there!

thanks for signing up for " <> con_name <> ".

please confirm your email address by clicking the link below:

" <> confirmation_url <> "

if you didn't sign up, you can safely ignore this email.

cheers!
kadei."

  send_email(email_config, email_address, subject, body)
}

fn send_email(
  email_config: EmailConfig,
  to_address: String,
  subject: String,
  body: String,
) -> Nil {
  case email_config {
    EmailConfig(api_key, from_name, from_address) ->
      send_via_zeptomail(
        api_key,
        from_name,
        from_address,
        to_address,
        subject,
        body,
      )
    NoEmail -> print_to_console(to_address, subject, body)
  }
}

fn send_via_zeptomail(
  api_key: String,
  from_name: String,
  from_address: String,
  to_address: String,
  subject: String,
  body: String,
) -> Nil {
  let email =
    zeptomail.Email(
      from: Addressee(from_name, from_address),
      to: [Addressee("", to_address)],
      reply_to: [],
      cc: [],
      bcc: [],
      body: TextBody(body),
      subject: subject,
    )

  let request = zeptomail.email_request(email, api_key)

  case hackney.send(request) {
    Ok(response) -> {
      case zeptomail.decode_email_response(response) {
        Ok(_) -> {
          logging.log(logging.Info, "Email sent to " <> to_address)
          Nil
        }
        Error(err) -> {
          logging.log(
            logging.Error,
            "Failed to send email to "
              <> to_address
              <> ": "
              <> format_api_error(err),
          )
          Nil
        }
      }
    }
    Error(_) -> {
      logging.log(logging.Error, "HTTP error sending email to " <> to_address)
      Nil
    }
  }
}

fn format_api_error(err: zeptomail.ApiError) -> String {
  case err {
    zeptomail.ApiError(code, message, _) -> code <> ": " <> message
    zeptomail.UnexpectedResponse(_) -> "Unexpected response from API"
  }
}

fn print_to_console(to_address: String, subject: String, body: String) -> Nil {
  io.println("")
  io.println("========================================")
  io.println("EMAIL (console fallback)")
  io.println("========================================")
  io.println("To: " <> to_address)
  io.println("Subject: " <> subject)
  io.println("")
  io.println(body)
  io.println("========================================")
  io.println("")
}
