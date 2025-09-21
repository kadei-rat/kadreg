import config
import errors.{type AppError, public_5xx_msg}
import gleam/erlang/process
import gleam/int
import gleam/result
import gleam/string
import global_value
import pog
import utils

pub fn connect(config: config.Config) -> Result(pog.Connection, String) {
  // global_value memoises the db connection. static key, assumes that a given
  // process will only ever use a single db config. (static key is generally
  // good practice with global_value which uses persistent_term)
  use <- global_value.create_with_unique_name("pog_conn")

  let pool_name = process.new_name(prefix: "kadreg_db")

  let url_conf =
    pog.url_config(pool_name, config.db_url)
    |> result.lazy_unwrap(fn() { panic as "Invalid DATABASE_URL" })

  let db_config =
    pog.Config(
      ..url_conf,
      database: url_conf.database <> config.db_name_suffix,
      pool_size: config.db_pool_size,
      pool_name: pool_name,
      rows_as_map: True,
    )

  case pog.start(db_config) {
    Ok(started) -> Ok(started.data)
    Error(error) ->
      Error("Database connection failed: " <> string.inspect(error))
  }
}

pub fn inspect_query_error(error: pog.QueryError) -> String {
  case error {
    pog.ConstraintViolated(_message, _constraint, detail) -> detail
    pog.PostgresqlError(code, name, message) ->
      "PostgreSQL error: " <> code <> " (" <> name <> "): " <> message
    pog.UnexpectedArgumentCount(expected, got) ->
      "Unexpected argument count: expected "
      <> int.to_string(expected)
      <> ", got "
      <> int.to_string(got)
    pog.UnexpectedArgumentType(expected, got) ->
      "Unexpected argument type: expected " <> expected <> ", got " <> got
    pog.UnexpectedResultType(decode_errors) ->
      utils.decode_errors_to_string(decode_errors)
    pog.QueryTimeout -> "Query timed out"
    pog.ConnectionUnavailable -> "Connection unavailable"
  }
}

pub fn to_app_error(error: pog.QueryError) -> AppError {
  case error {
    pog.ConstraintViolated(_message, _constraint, detail) ->
      errors.validation_error(detail, string.inspect(error))
    pog.PostgresqlError(code, name, message) ->
      errors.internal_error(
        public_5xx_msg,
        "PostgreSQL error: " <> code <> " (" <> name <> "): " <> message,
      )
    pog.UnexpectedArgumentCount(expected, got) ->
      errors.internal_error(
        public_5xx_msg,
        "Unexpected argument count: expected "
          <> int.to_string(expected)
          <> ", got "
          <> int.to_string(got),
      )
    pog.UnexpectedArgumentType(expected, got) ->
      errors.internal_error(
        public_5xx_msg,
        "Unexpected argument type: expected " <> expected <> ", got " <> got,
      )
    pog.UnexpectedResultType(decode_errors) ->
      errors.internal_error(
        public_5xx_msg,
        utils.decode_errors_to_string(decode_errors),
      )
    pog.QueryTimeout ->
      errors.internal_error(public_5xx_msg, "Database query timed out")
    pog.ConnectionUnavailable ->
      errors.internal_error(public_5xx_msg, "Database connection unavailable")
  }
}
