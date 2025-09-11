import config
import database
import gleam/io

pub fn main() -> Nil {
  io.println("Testing database connection...")

  let conf = config.load()
  case database.connect(conf) {
    Ok(_conn) -> {
      io.println("✅ Database connection successful!")
    }
    Error(error) -> {
      io.println("❌ Database connection failed:")
      io.println(error)
    }
  }
}
