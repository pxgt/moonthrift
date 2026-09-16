// Blackbox tests run against the package's public API. Use `@moonthrift` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "lexer handles comments literals and punctuation" {
  let idl =
    #|// comment
    #|struct User { 1: required string name, 2: optional i64 score = -4 }
    #|const string mode = 'fast'
    #|
  let tokens = @moonthrift.lex(idl)
  assert_eq(tokens.length(), 23)
  assert_true(tokens[0].kind is Identifier("struct"))
  assert_true(tokens[3].kind is IntegerLiteral(1L))
  assert_true(tokens[22].kind is End)
}

///|
test "lexer decodes string escapes and records locations" {
  let tokens = @moonthrift.lex(
    "\nconst string x = \"a\\n\\t\\\"b\"",
    source="demo.thrift",
  )
  assert_true(tokens[4].kind is StringLiteral("a\n\t\"b"))
  assert_eq(tokens[0].span.line, 2)
  assert_eq(tokens[0].span.column, 1)
  assert_eq(tokens[0].span.source, "demo.thrift")
}

///|
test "lexer rejects invalid characters" {
  try @moonthrift.lex("struct @") catch {
    UnexpectedCharacter('@', span) => assert_eq(span.column, 8)
    _ => fail("unexpected lexical error")
  } noraise {
    _ => fail("expected lexing to fail")
  }
}

///|
test "parser covers the principal Thrift declarations" {
  let idl =
    #|namespace mbt sample.api
    #|include "common.thrift"
    #|typedef i64 UserId
    #|enum Role { USER = 1, ADMIN }
    #|struct User {
    #|  1: required UserId id
    #|  2: optional string name = "guest" (sensitive = "false")
    #|}
    #|union Choice { 1: string text, 2: i64 number }
    #|exception NotFound { 1: string message }
    #|const list<i32> PORTS = [80, 443]
    #|service Users extends BaseUsers {
    #|  User get(1: UserId id) throws (1: NotFound missing)
    #|  oneway void ping()
    #|}
    #|
  let schema = @moonthrift.parse_idl(idl, source="users.thrift")
  assert_eq(schema.headers.length(), 2)
  assert_eq(schema.definitions.length(), 7)
  assert_eq(schema.definitions[0].name(), "UserId")
  assert_true(schema.definitions[1] is Enum(name="Role", members=[..], ..))
  assert_true(schema.definitions[2] is Struct(name="User", fields=[_, _], ..))
  assert_true(
    schema.definitions[6]
    is Service(name="Users", extends=Some("BaseUsers"), functions=[_, _], ..),
  )
}

///|
test "parser handles map and floating constants" {
  let schema = @moonthrift.parse_idl(
    "const map<string, double> weights = {\"a\": 1.25, \"b\": -2.5e2}",
  )
  guard schema.definitions is [Const(value=MapValue(entries), ..)] else {
    fail("expected map constant")
  }
  assert_eq(entries.length(), 2)
  assert_true(entries[1].1 is DoubleValue(-250.0))
}
