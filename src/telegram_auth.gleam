import errors.{type AppError}
import gleam/bit_array
import gleam/crypto
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

pub type TelegramLoginData {
  TelegramLoginData(
    id: Int,
    first_name: String,
    last_name: Option(String),
    username: Option(String),
    photo_url: Option(String),
    auth_date: Int,
    hash: String,
  )
}

const max_auth_age_seconds = 86_400

/// Verify Telegram login data and return the parsed data if valid.
pub fn verify_login(
  query_params: List(#(String, String)),
  bot_token: String,
) -> Result(TelegramLoginData, AppError) {
  use login_data <- result.try(parse_login_data(query_params))
  use <- verify_hash(login_data, query_params, bot_token)
  use <- verify_auth_date(login_data)
  Ok(login_data)
}

fn parse_login_data(
  params: List(#(String, String)),
) -> Result(TelegramLoginData, AppError) {
  use id_str <- result.try(get_param(params, "id"))
  use id <- result.try(
    int.parse(id_str)
    |> result.replace_error(errors.validation_error(
      "Invalid Telegram login data",
      "Failed to parse Telegram id as integer",
    )),
  )

  use first_name <- result.try(get_param(params, "first_name"))
  use auth_date_str <- result.try(get_param(params, "auth_date"))
  use auth_date <- result.try(
    int.parse(auth_date_str)
    |> result.replace_error(errors.validation_error(
      "Invalid Telegram login data",
      "Failed to parse auth_date as integer",
    )),
  )
  use hash <- result.try(get_param(params, "hash"))

  let last_name = get_optional_param(params, "last_name")
  let username = get_optional_param(params, "username")
  let photo_url = get_optional_param(params, "photo_url")

  Ok(TelegramLoginData(
    id: id,
    first_name: first_name,
    last_name: last_name,
    username: username,
    photo_url: photo_url,
    auth_date: auth_date,
    hash: hash,
  ))
}

fn get_param(
  params: List(#(String, String)),
  key: String,
) -> Result(String, AppError) {
  params
  |> list.find(fn(pair) { pair.0 == key })
  |> result.map(fn(pair) { pair.1 })
  |> result.replace_error(errors.validation_error(
    "Invalid Telegram login data",
    "Missing required field: " <> key,
  ))
}

fn get_optional_param(
  params: List(#(String, String)),
  key: String,
) -> Option(String) {
  params
  |> list.find(fn(pair) { pair.0 == key })
  |> result.map(fn(pair) { pair.1 })
  |> option.from_result
}

fn verify_hash(
  login_data: TelegramLoginData,
  query_params: List(#(String, String)),
  bot_token: String,
  next: fn() -> Result(TelegramLoginData, AppError),
) -> Result(TelegramLoginData, AppError) {
  let data_check_string = build_data_check_string(query_params)

  let secret_key = crypto.hash(crypto.Sha256, bit_array.from_string(bot_token))

  let computed_hash =
    crypto.hmac(
      bit_array.from_string(data_check_string),
      crypto.Sha256,
      secret_key,
    )
    |> bit_array.base16_encode
    |> string.lowercase

  let provided_hash = string.lowercase(login_data.hash)

  case
    crypto.secure_compare(
      bit_array.from_string(computed_hash),
      bit_array.from_string(provided_hash),
    )
  {
    True -> next()
    False ->
      Error(errors.authentication_error(
        "Invalid Telegram login: hash verification failed",
      ))
  }
}

fn build_data_check_string(params: List(#(String, String))) -> String {
  params
  |> list.filter(fn(pair) { pair.0 != "hash" })
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  |> list.map(fn(pair) { pair.0 <> "=" <> pair.1 })
  |> string.join("\n")
}

fn verify_auth_date(
  login_data: TelegramLoginData,
  next: fn() -> Result(TelegramLoginData, AppError),
) -> Result(TelegramLoginData, AppError) {
  let current_time = current_unix_time()
  let age = current_time - login_data.auth_date

  case age > 0 && age < max_auth_age_seconds {
    True -> next()
    False ->
      Error(errors.authentication_error(
        "Telegram login has expired. Please try again.",
      ))
  }
}

@external(erlang, "os", "system_time")
fn system_time_impl(unit: Atom) -> Int

type Atom

@external(erlang, "erlang", "binary_to_atom")
fn binary_to_atom(binary: String) -> Atom

fn current_unix_time() -> Int {
  system_time_impl(binary_to_atom("second"))
}
