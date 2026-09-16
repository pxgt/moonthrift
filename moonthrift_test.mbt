// Blackbox tests run against the package's public API. Use `@moonthrift` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "lexer handles comments literals and punctuation" {
  let tokens = @moonthrift.lex(
    (
      #|// comment
      #|struct User { 1: required string name, 2: optional i64 score = -4 }
      #|const string mode = 'fast'
      #|,
    ),
  )
  assert_eq(tokens.length(), 24)
  assert_true(tokens[0].kind is Identifier("struct"))
  assert_true(tokens[3].kind is IntegerLiteral(1L))
  assert_true(tokens[23].kind is End)
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
