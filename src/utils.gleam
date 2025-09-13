import gleam/dynamic/decode
import gleam/list
import gleam/string

pub fn decode_errors_to_string(errors: List(decode.DecodeError)) -> String {
  errors
  |> list.map(fn(error) {
    let decode.DecodeError(expected, found, path) = error
    "Problem with field "
    <> string.join(path, ".")
    <> " (expected "
    <> expected
    <> ", found "
    <> found
    <> ")"
  })
  |> string.join(". ")
}

pub fn find_first(list: List(a), predicate: fn(a) -> Bool) -> Result(a, Nil) {
  case list {
    [] -> Error(Nil)
    [first, ..rest] ->
      case predicate(first) {
        True -> Ok(first)
        False -> find_first(rest, predicate)
      }
  }
}
