import config
import gleam/erlang/process
import gleam/string
import global_value
import pog

pub fn connect(config: config.Config) -> Result(pog.Connection, String) {
  // global_value memoises the db connection. static key, assumes that a given
  // process will only ever use a single db config. (static key is generally
  // good practice with global_value which uses persistent_term)
  use <- global_value.create_with_unique_name("pog_conn")

  let pool_name = process.new_name(prefix: "kadreg_db")

  let db_config =
    pog.Config(
      host: config.db_host,
      port: config.db_port,
      database: config.db_name,
      user: config.db_user,
      password: config.db_password,
      ssl: pog.SslDisabled,
      connection_parameters: [],
      pool_size: config.db_pool_size,
      queue_target: 50,
      queue_interval: 1000,
      idle_interval: 1000,
      trace: False,
      ip_version: pog.Ipv4,
      pool_name: pool_name,
      rows_as_map: True,
    )

  case pog.start(db_config) {
    Ok(started) -> Ok(started.data)
    Error(error) ->
      Error("Database connection failed: " <> string.inspect(error))
  }
}
