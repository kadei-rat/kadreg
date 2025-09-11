import envoy
import gleam/int
import gleam/option.{type Option}
import gleam/result

pub type Environment {
  Dev
  Prod
}

pub type Config {
  Config(
    // general config
    kadreg_env: Environment,
    // database configuration
    db_host: String,
    db_port: Int,
    db_name: String,
    db_user: String,
    db_password: Option(String),
    db_pool_size: Int,
    // web server configuration
    server_port: Int,
    secret_key_base: String,
  )
}

fn parse_environment(env_str: String) -> Environment {
  case env_str {
    "prod" -> Prod
    "dev" -> Dev
    _ -> panic as "Invalid KADREG_ENV value"
  }
}

pub fn load() -> Config {
  let kadreg_env =
    envoy.get("KADREG_ENV")
    |> result.unwrap("dev")
    |> parse_environment

  let db_host =
    envoy.get("DB_HOST")
    |> result.unwrap("localhost")

  let db_port =
    envoy.get("DB_PORT")
    |> result.try(int.parse)
    |> result.unwrap(5432)

  let db_name =
    envoy.get("DB_NAME")
    |> result.unwrap("kadreg")

  let db_user =
    envoy.get("DB_USER")
    |> result.unwrap("")

  let db_password = case envoy.get("DB_PASSWORD") {
    Ok(pwd) -> option.Some(pwd)
    Error(_) -> option.None
  }

  let db_pool_size =
    envoy.get("DB_POOL_SIZE")
    |> result.try(int.parse)
    |> result.unwrap(10)

  let server_port =
    envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(8621)

  let secret_key_base =
    envoy.get("SECRET_KEY_BASE")
    |> result.unwrap("dev_secret_key")

  // Security check: don't allow production with default secret
  case kadreg_env, secret_key_base {
    Prod, "dev_secret_key" ->
      panic as "Cannot use default secret key in production! Set SECRET_KEY_BASE environment variable."
    _, _ -> Nil
  }

  Config(
    kadreg_env: kadreg_env,
    db_host: db_host,
    db_port: db_port,
    db_name: db_name,
    db_user: db_user,
    db_password: db_password,
    db_pool_size: db_pool_size,
    server_port: server_port,
    secret_key_base: secret_key_base,
  )
}
