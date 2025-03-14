import gleeunit
import gleeunit/should
import qwjz.{
  type Binding, type Env, type ExprC, type Value, AppC, BoolV, IdC, IfC, NumC,
  NumV, StrC, StrV, interp, parse, parse_and_interp, top_env,
}

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn interp_test() {
  1
  |> should.equal(1)
}

// Test basic values
pub fn basic_values_test() {
  // Test numbers
  interp(NumC(42), top_env)
  |> should.equal(Ok(NumV(42)))

  // Test strings
  interp(StrC("hello"), top_env)
  |> should.equal(Ok(StrV("hello")))

  // Test boolean literals
  interp(IdC("true"), top_env)
  |> should.equal(Ok(BoolV(True)))

  interp(IdC("false"), top_env)
  |> should.equal(Ok(BoolV(False)))
}

// Test arithmetic operations
pub fn arithmetic_test() {
  // Test addition
  interp(AppC(IdC("+"), [NumC(3), NumC(4)]), top_env)
  |> should.equal(Ok(NumV(7)))

  // Test multiplication
  interp(AppC(IdC("*"), [NumC(3), NumC(4)]), top_env)
  |> should.equal(Ok(NumV(12)))

  // Test division
  interp(AppC(IdC("/"), [NumC(10), NumC(2)]), top_env)
  |> should.equal(Ok(NumV(5)))
}

// Test if expressions
pub fn if_test() {
  // Test true branch
  interp(IfC(IdC("true"), NumC(42), NumC(0)), top_env)
  |> should.equal(Ok(NumV(42)))

  // Test false branch
  interp(IfC(IdC("false"), NumC(0), NumC(42)), top_env)
  |> should.equal(Ok(NumV(42)))
}

// Test string concatenation
pub fn string_concat_test() {
  interp(AppC(IdC("++"), [StrC("Hello "), StrC("World")]), top_env)
  |> should.equal(Ok(StrV("Hello World")))
}

// Test comparison operations
pub fn comparison_test() {
  // Test less than or equal
  interp(AppC(IdC("<="), [NumC(3), NumC(5)]), top_env)
  |> should.equal(Ok(BoolV(True)))

  // Test equality
  interp(AppC(IdC("equal?"), [NumC(5), NumC(5)]), top_env)
  |> should.equal(Ok(BoolV(True)))
}

// Test parser
pub fn parser_test() {
  // Test parsing numbers
  parse("42")
  |> should.equal(Ok(NumC(42)))

  // Test parsing strings
  parse("\"hello\"")
  |> should.equal(Ok(StrC("hello")))

  // Test parsing booleans
  parse("true")
  |> should.equal(Ok(IdC("true")))

  parse("false")
  |> should.equal(Ok(IdC("false")))

  // Test parsing identifiers
  parse("x")
  |> should.equal(Ok(IdC("x")))

  // Test parsing with whitespace
  parse("  42  ")
  |> should.equal(Ok(NumC(42)))

  // Test parsing and interpreting together
  parse_and_interp("42")
  |> should.equal(Ok(NumV(42)))

  parse_and_interp("\"hello\"")
  |> should.equal(Ok(StrV("hello")))

  parse_and_interp("true")
  |> should.equal(Ok(BoolV(True)))
}

// arithmetic errors tests
pub fn arithmetic_error_test() {
  // adding a number to a string
  interp(AppC(IdC("+"), [NumC(3), StrC("hello")]), top_env)
  |> should.equal(Error("QWJZ: incorrect call to + expression"))

  // division by zero
  interp(AppC(IdC("/"), [NumC(5), NumC(0)]), top_env)
  |> should.equal(Error("QWJZ: Division by zero"))
}
