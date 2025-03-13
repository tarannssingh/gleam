import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should

pub type ExprC {
  NumC(n: Int)
  IfC(cond: ExprC, th: ExprC, el: ExprC)
  IdC(s: String)
  LamC(args: List(String), body: ExprC)
  AppC(fun: ExprC, args: List(ExprC))
  StrC(s: String)
}

pub type Value {
  NumV(n: Int)
  BoolV(b: Bool)
  ClosV(args: List(String), body: ExprC, env: Env)
  PrimV(op: String)
  StrV(s: String)
}

pub type Env {
  Env(lst: List(Binding))
}

pub type Binding {
  Binding(id: String, val: Value)
}

// define top-env
pub const top_env = Env(
  [
    Binding("+", PrimV("+")),
    Binding("-", PrimV("-")),
    Binding("*", PrimV("*")),
    Binding("/", PrimV("/")),
    Binding("<=", PrimV("<=")),
    Binding("equal?", PrimV("equal?")),
    Binding("println", PrimV("println")),
    Binding("read-num", PrimV("read-num")),
    Binding("read-str", PrimV("read-str")),
    Binding("seq", PrimV("seq")),
    Binding("++", PrimV("++")),
    Binding("true", BoolV(True)),
    Binding("false", BoolV(False)),
  ],
)

// lookup helper for interp to look fo bound variables and primitive functions
pub fn lookup(for: String, e: List(Binding)) -> Result(Value, String) {
  case e {
    [] ->
      case for {
        "error" -> Error("QWJZ: user-error")
        _ -> Error("QWJZ: name not found #{for}")
      }
    [Binding(id, val), ..rest] ->
      case for == id {
        True -> Ok(val)
        False -> lookup(for, rest)
      }
  }
}

// interp takes in a ExprC and returns a Value
// NOTE: wrap all values in Ok() as seen below
pub fn interp(exp: ExprC, env: Env) -> Result(Value, String) {
  case exp {
    NumC(n) -> Ok(NumV(n))
    StrC(s) -> Ok(StrV(s))
    IdC(s) -> lookup(s, env.lst)
    IfC(cond, th, el) ->
      case interp(cond, env) {
        Ok(BoolV(b)) ->
          case b {
            True -> interp(th, env)
            False -> interp(el, env)
          }
        _ -> Error("QWJZ: expected bool result from cond but got #{res}")
      }
    AppC(fun, args) ->
      case interp(fun, env) {
        Ok(PrimV("seq")) ->
          result.unwrap(
            list.last(list.map(args, fn(x: ExprC) { interp(x, env) })),
            Error("QWJZ: unwrap error"),
          )
        Ok(PrimV("++")) ->
          Ok(
            StrV(
              list.fold(args, "", fn(s, r) {
                case r {
                  StrC(str) -> string.append(s, str)
                  NumC(n) -> string.append(s, int.to_string(n))
                  _ ->
                    result.unwrap(
                      Error("QWJZ: incorrect type in call of ++, given #{r}"),
                      "default",
                    )
                }
              }),
            ),
          )
        Ok(PrimV("+")) ->
          case list.map(args, fn(a) { interp(a, env) }) {
            [Ok(NumV(n1)), Ok(NumV(n2))] -> Ok(NumV(n1 + n2))
            _ -> Error("QWJZ: incorrect call to + expression")
          }
        Ok(PrimV("-")) ->
          case list.map(args, fn(a) { interp(a, env) }) {
            [Ok(NumV(n1)), Ok(NumV(n2))] -> Ok(NumV(n1 - n2))
            _ -> Error("QWJZ: incorrect call to - expression")
          }
        Ok(PrimV("*")) ->
          case list.map(args, fn(a) { interp(a, env) }) {
            [Ok(NumV(n1)), Ok(NumV(n2))] -> Ok(NumV(n1 * n2))
            _ -> Error("QWJZ: incorrect call to * expression")
          }
        Ok(PrimV("/")) ->
          case list.map(args, fn(a) { interp(a, env) }) {
            [Ok(NumV(n1)), Ok(NumV(n2))] -> Ok(NumV(n1 / n2))
            _ -> Error("QWJZ: incorrect call to / expression")
          }
        Ok(PrimV("<=")) ->
          case list.map(args, fn(a) { interp(a, env) }) {
            [Ok(NumV(n1)), Ok(NumV(n2))] ->
              case n1 <= n2 {
                True -> Ok(BoolV(True))
                False -> Ok(BoolV(False))
              }
            _ -> Error("QWJZ: incorrect call to <= expression")
          }
        Ok(PrimV("equal?")) ->
          case list.map(args, fn(a) { interp(a, env) }) {
            [Ok(NumV(n1)), Ok(NumV(n2))] ->
              case n1 == n2 {
                True -> Ok(BoolV(True))
                False -> Ok(BoolV(False))
              }
            [Ok(StrV(s1)), Ok(StrV(s2))] ->
              case s1 == s2 {
                True -> Ok(BoolV(True))
                False -> Ok(BoolV(False))
              }
            [Ok(BoolV(b1)), Ok(BoolV(b2))] ->
              case b1 == b2 {
                True -> Ok(BoolV(True))
                False -> Ok(BoolV(False))
              }
            _ -> Ok(BoolV(False))
          }
        Ok(PrimV("println")) ->
          case list.map(args, fn(a) { interp(a, env) }) {
            [Ok(StrV(s1))] -> {
              io.println(s1)
              Ok(StrV(s1))
            }
            _ -> Error("QWJZ: incorrect call to println expression")
          }
        _ -> Error("QWJZ: unknown expression #{fun}")
      }
    LamC(args, body) -> Ok(ClosV(args, body, env))
  }
}

// Test Example
pub fn one_test() {
  interp(
    AppC(IdC("+"), [
      AppC(IdC("/"), [NumC(10), NumC(5)]),
      AppC(IdC("*"), [AppC(IdC("-"), [NumC(10), NumC(5)]), NumC(2)]),
    ]),
    top_env,
  )
  |> should.equal(Ok(NumV(12)))
}

// main sets us up for testing
pub fn main() {
  gleeunit.main()
}

// Simple parser for basic expressions
pub fn parse(input: String) -> Result(ExprC, String) {
  // Remove whitespace
  let input = string.trim(input)

  // Try to parse as number first
  case int.parse(input) {
    Ok(n) -> Ok(NumC(n))
    Error(_) -> {
      // Try to parse as string if it starts with quotes
      case string.starts_with(input, "\"") {
        True -> {
          case string.ends_with(input, "\"") {
            True ->
              Ok(
                StrC(string.replace(
                  string.slice(input, 1, string.length(input) - 1),
                  "\"",
                  "",
                )),
              )
            False -> Error("QWJZ: Unterminated string")
          }
        }
        False -> {
          // Try to parse as identifier
          case input {
            "true" -> Ok(IdC("true"))
            "false" -> Ok(IdC("false"))
            _ -> Ok(IdC(input))
          }
        }
      }
    }
  }
}

// Example of parsing and interpreting
pub fn parse_and_interp(input: String) -> Result(Value, String) {
  case parse(input) {
    Ok(expr) -> interp(expr, top_env)
    Error(e) -> Error(e)
  }
}
