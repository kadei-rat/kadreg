import config.{type Config}
import database
import errors.{type AppError, public_5xx_msg}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/otp/actor
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import logging
import models/admin_audit.{type AuditLogEntry}
import models/members.{type MemberRecord, type MemberStats}
import models/pending_members.{type PendingMemberRecord}
import models/registrations.{type Registration, type RegistrationWithMember}
import pog

// Public api

pub type DbCoordName =
  process.Name(Message)

pub type Message {
  MemberQuery(
    query: pog.Query(MemberRecord),
    reply_to: Subject(Result(pog.Returned(MemberRecord), AppError)),
  )
  PendingMemberQuery(
    query: pog.Query(PendingMemberRecord),
    reply_to: Subject(Result(pog.Returned(PendingMemberRecord), AppError)),
  )
  StatsQuery(
    query: pog.Query(MemberStats),
    reply_to: Subject(Result(pog.Returned(MemberStats), AppError)),
  )
  AuditQuery(
    query: pog.Query(AuditLogEntry),
    reply_to: Subject(Result(pog.Returned(AuditLogEntry), AppError)),
  )
  RegistrationQuery(
    query: pog.Query(Registration),
    reply_to: Subject(Result(pog.Returned(Registration), AppError)),
  )
  RegistrationWithMemberQuery(
    query: pog.Query(RegistrationWithMember),
    reply_to: Subject(Result(pog.Returned(RegistrationWithMember), AppError)),
  )
  NoResultQuery(
    query: pog.Query(Nil),
    reply_to: Subject(Result(pog.Returned(Nil), AppError)),
  )
}

pub fn member_query(
  query: pog.Query(MemberRecord),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(MemberRecord), AppError) {
  call_db_coordinator(MemberQuery(query, _), db_coord_name)
}

pub fn pending_member_query(
  query: pog.Query(PendingMemberRecord),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(PendingMemberRecord), AppError) {
  call_db_coordinator(PendingMemberQuery(query, _), db_coord_name)
}

pub fn stats_query(
  query: pog.Query(MemberStats),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(MemberStats), AppError) {
  call_db_coordinator(StatsQuery(query, _), db_coord_name)
}

pub fn audit_query(
  query: pog.Query(AuditLogEntry),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(AuditLogEntry), AppError) {
  call_db_coordinator(AuditQuery(query, _), db_coord_name)
}

pub fn registration_query(
  query: pog.Query(Registration),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(Registration), AppError) {
  call_db_coordinator(RegistrationQuery(query, _), db_coord_name)
}

pub fn registration_with_member_query(
  query: pog.Query(RegistrationWithMember),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(RegistrationWithMember), AppError) {
  call_db_coordinator(RegistrationWithMemberQuery(query, _), db_coord_name)
}

pub fn noresult_query(
  query: pog.Query(Nil),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(Nil), AppError) {
  call_db_coordinator(NoResultQuery(query, _), db_coord_name)
}

pub fn start(
  conf: Config,
  name: DbCoordName,
) -> Result(actor.Started(_), actor.StartError) {
  actor.new(State(
    conn: None,
    conf: conf,
    last_query_time: None,
    // use the same name for each instance of the connection pool, guaranteeing
    // we only run one at once
    pool_name: process.new_name(prefix: "db_pool"),
  ))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

// Private

type DbPool {
  DbPool(conn: pog.Connection, pid: process.Pid, created_at: Timestamp)
}

type State {
  State(
    conn: Option(DbPool),
    conf: Config,
    last_query_time: Option(Timestamp),
    pool_name: process.Name(pog.Message),
    // query_cache: Map(
  )
}

fn call_db_coordinator(
  query: _,
  db_coord_name: DbCoordName,
) -> Result(_, AppError) {
  process.call(process.named_subject(db_coord_name), 10_000, query)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    MemberQuery(query, reply_to) -> run_query(state, query, reply_to)
    PendingMemberQuery(query, reply_to) -> run_query(state, query, reply_to)
    StatsQuery(query, reply_to) -> run_query(state, query, reply_to)
    AuditQuery(query, reply_to) -> run_query(state, query, reply_to)
    RegistrationQuery(query, reply_to) -> run_query(state, query, reply_to)
    RegistrationWithMemberQuery(query, reply_to) ->
      run_query(state, query, reply_to)
    NoResultQuery(query, reply_to) -> run_query(state, query, reply_to)
  }
}

fn run_query(
  state: State,
  query: pog.Query(t),
  reply_to: Subject(Result(pog.Returned(t), AppError)),
) -> actor.Next(State, Message) {
  case state {
    State(Some(DbPool(_, pid, _)), conf, last_query_time, _) -> {
      case should_restart_conn(last_query_time, conf) {
        True -> {
          logging.log(logging.Info, "Restarting stale DB connection")
          process.send_exit(pid)
          create_conn_and_execute_query(state, query, reply_to)
        }
        False -> {
          execute_query_on_conn(state, query, reply_to)
        }
      }
    }
    State(None, _, _, _) -> {
      create_conn_and_execute_query(state, query, reply_to)
    }
  }
}

fn should_restart_conn(last_query_time: Option(Timestamp), conf: Config) -> Bool {
  let now = timestamp.system_time()
  case last_query_time {
    Some(last_time) -> {
      let time_elapsed = timestamp.difference(now, last_time)
      duration.compare(
        time_elapsed,
        duration.seconds(conf.max_db_pool_lifetime),
      )
      == order.Gt
    }
    None -> False
  }
}

fn execute_query_on_conn(
  state: State,
  query: pog.Query(t),
  reply_to: Subject(Result(pog.Returned(t), AppError)),
) -> actor.Next(State, Message) {
  let assert State(Some(DbPool(conn, pid, created_at)), _, _, _) = state
  let now = timestamp.system_time()
  case pog.execute(query, conn) {
    Error(pog.QueryTimeout) ->
      handle_query_timeout(state, pid, created_at, now, reply_to, query)
    Error(other_error) -> {
      process.send(reply_to, Error(database.to_app_error(other_error)))
      actor.continue(state)
    }
    Ok(result) -> {
      process.send(reply_to, Ok(result))
      actor.continue(State(..state, last_query_time: Some(now)))
    }
  }
}

fn create_conn_and_execute_query(
  state: State,
  query: pog.Query(t),
  reply_to: Subject(Result(pog.Returned(t), AppError)),
) -> actor.Next(State, Message) {
  let now = timestamp.system_time()
  logging.log(logging.Info, "Initialising DB connection")
  case database.connect(state.conf, state.pool_name) {
    Ok(actor.Started(pid, data)) -> {
      logging.log(logging.Info, "DB connection successful")
      let new_state =
        State(
          ..state,
          conn: Some(DbPool(conn: data, pid: pid, created_at: now)),
          last_query_time: Some(now),
        )
      case pog.execute(query, data) {
        // For the initial query after a connection, don't handle QueryTimeout
        // separately; we never recycle a young pool
        Ok(result) -> {
          process.send(reply_to, Ok(result))
          actor.continue(new_state)
        }
        Error(err) -> {
          process.send(reply_to, Error(database.to_app_error(err)))
          actor.continue(new_state)
        }
      }
    }
    Error(err) -> {
      logging.log(
        logging.Warning,
        "DB connection failed: " <> string.inspect(err),
      )
      process.send(
        reply_to,
        Error(errors.internal_error(
          public_5xx_msg,
          "Error connecting to database: " <> string.inspect(err),
        )),
      )
      actor.continue(state)
    }
  }
}

fn handle_query_timeout(
  state: State,
  pid: process.Pid,
  created_at: Timestamp,
  now: Timestamp,
  reply_to: Subject(Result(pog.Returned(t), AppError)),
  query: pog.Query(t),
) -> actor.Next(State, Message) {
  let conn_age = timestamp.difference(now, created_at)
  // query timeout is how neon having killed all connections seems to manifest.
  // restart the pool and re-query.. but debounce to once per minute to avoid a
  // pool restart loop in case the problem is something else
  case duration.compare(conn_age, duration.minutes(1)) {
    order.Gt -> {
      logging.log(
        logging.Warning,
        "Query timeout on connection older than 1 minute - restarting connection",
      )
      process.send_exit(pid)
      create_conn_and_execute_query(state, query, reply_to)
    }
    _ -> {
      process.send(reply_to, Error(database.to_app_error(pog.QueryTimeout)))
      actor.continue(state)
    }
  }
}
