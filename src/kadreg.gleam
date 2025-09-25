import config
import db_coordinator
import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import logging
import mist
import router
import wisp
import wisp/wisp_mist

pub fn main() {
  process.sleep_forever()
}

pub fn start(_app, _type) -> Result(process.Pid, actor.StartError) {
  wisp.configure_logger()
  logging.configure()
  logging.set_level(logging.Debug)

  logging.log(logging.Info, "Starting kadreg top-level supervisor")

  let conf = config.load()

  let db_coord_name = process.new_name(prefix: "db_coordinator")

  let db_worker =
    supervision.worker(fn() { db_coordinator.start(conf, db_coord_name) })

  let web_server =
    wisp_mist.handler(
      router.handle_request(_, conf, db_coord_name),
      conf.secret_key_base,
    )
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(conf.server_port)
    |> mist.supervised

  case
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(db_worker)
    |> supervisor.add(web_server)
    |> supervisor.start
  {
    Ok(actor.Started(pid, _data)) -> {
      Ok(pid)
    }
    Error(reason) -> Error(reason)
  }
}
