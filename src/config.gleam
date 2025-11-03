import envoy
import gleam/int
import gleam/result

pub type Environment {
  Dev
  Prod
}

pub type Config {
  Config(
    // general config
    kadreg_env: Environment,
    con_name: String,
    base_url: String,
    registration_open: Bool,
    // database configuration
    db_url: String,
    db_name_suffix: String,
    db_pool_size: Int,
    // in seconds
    max_db_pool_lifetime: Int,
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

  let con_name =
    envoy.get("CON_NAME")
    |> result.unwrap("Pawsome")

  let base_url =
    envoy.get("BASE_URL")
    |> result.unwrap("http://localhost:8621")

  let registration_open =
    envoy.get("REGISTRATION_OPEN")
    |> result.unwrap("false")
    == "true"

  let db_url =
    envoy.get("DATABASE_URL")
    |> result.unwrap("postgresql://localhost:5432/kadreg?sslmode=disable")

  let db_name_suffix =
    envoy.get("DB_NAME_SUFFIX")
    |> result.unwrap("")

  let db_pool_size =
    envoy.get("DB_POOL_SIZE")
    |> result.try(int.parse)
    |> result.unwrap(5)

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

  // in integer seconds
  let max_db_pool_lifetime =
    envoy.get("MAX_DB_POOL_LIFETIME")
    |> result.try(int.parse)
    |> result.unwrap(4 * 60)

  Config(
    kadreg_env: kadreg_env,
    con_name: con_name,
    base_url: base_url,
    registration_open: registration_open,
    db_url: db_url,
    db_name_suffix: db_name_suffix,
    db_pool_size: db_pool_size,
    max_db_pool_lifetime: max_db_pool_lifetime,
    server_port: server_port,
    secret_key_base: secret_key_base,
  )
}
