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

// lookup helper for interp to look for bound variables and primitive functions
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
        Ok(PrimV("++")) -> {
            let evaluated_args = list.map(args, fn(a) { interp(a, env) })
            case list.all(evaluated_args, fn(a) {
                case a {
                    Ok(StrV(_)) -> True
                    Ok(NumV(_)) -> True
                    _ -> False
                }
            }) {
                True -> {
                    let concat_result = list.fold(evaluated_args, "", fn(s, r) {
                        case r {
                            Ok(StrV(str)) -> string.append(s, str)
                            Ok(NumV(n)) -> string.append(s, int.to_string(n))
                            _ -> s
                        }
                    })
                    Ok(StrV(concat_result))
                }
                False -> Error("QWJZ: incorrect type in call of ++, expected only strings and numbers")
            }
        }
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
            [Ok(NumV(n1)), Ok(NumV(0))] -> Error("QWJZ: Division by zero")
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
                [Ok(NumV(n))] -> {
                    io.println(int.to_string(n))
                    Ok(StrV(int.to_string(n)))    
                }
                _ -> Error("QWJZ: incorrect call to println expression, expected string or number")
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

// parser for basic expressions
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

// demo
pub fn demo(env: Env) {
    let run_demo = AppC(
        IdC("seq"),
        [
            AppC(IdC("println"), [StrC("demo: performing operations...")]),

            // operations
            AppC(IdC("println"), [AppC(IdC("++"), [StrC("4 + 3 = "), AppC(IdC("+"), [NumC(4), NumC(3)])])]),
            AppC(IdC("println"), [AppC(IdC("++"), [StrC("12 - 4 = "), AppC(IdC("-"), [NumC(12), NumC(4)])])]),
            AppC(IdC("println"), [AppC(IdC("++"), [StrC("9 * 7 = "), AppC(IdC("*"), [NumC(9), NumC(7)])])]),
            AppC(IdC("println"), [AppC(IdC("++"), [StrC("30 / 5 = "), AppC(IdC("/"), [NumC(30), NumC(5)])])]),

            // comparison
            AppC(IdC("println"), [StrC("is 5 <= 10...?")]),
            IfC(
                AppC(IdC("<="), [NumC(5), NumC(10)]),
                AppC(IdC("println"), [StrC("yes it is!")]),
                AppC(IdC("println"), [StrC("no it's not!")])
            ),

            // string concatenation
            AppC(IdC("println"), [StrC("demo: string concatenation...")]),
            AppC(IdC("println"), [AppC(IdC("++"), [StrC("Hello, "), StrC("world")])]),

            AppC(IdC("println"), [StrC("demo complete!")])
        ]
    )

    let _ = interp(run_demo, env)
}

// main
pub fn main() {
  let env = top_env
  demo(env)
  gleeunit.main()
}

