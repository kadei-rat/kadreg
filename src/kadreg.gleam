import config
import database
import gleam/erlang/process
import mist
import router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let conf = config.load()

  let db = case database.connect(conf) {
    Ok(connection) -> {
      connection
    }
    Error(_err) -> {
      panic as "Database connection failed"
    }
  }

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request(_, db), conf.secret_key_base)
    |> mist.new
    |> mist.port(conf.server_port)
    |> mist.start

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}
