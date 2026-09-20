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
test "parser preserves line and block documentation" {
  let idl =
    #|/** Account data.
    #| * Kept across releases.
    #| */
    #|struct User {
    #|  /// Stable identifier.
    #|  1: required i64 id
    #|}
    #|/// Available roles.
    #|enum Role {
    #|  /// Regular member.
    #|  USER = 1
    #|}
    #|
  let schema = @moonthrift.parse_idl(idl)
  guard schema.definitions
    is [
      Struct(annotations=struct_annotations, fields=[field], ..),
      Enum(annotations=enum_annotations, members=[enum_member], ..),
    ] else {
    fail("expected documented declarations")
  }
  assert_true(
    struct_annotations.contains({
      key: "moonbit.doc",
      value: Some("Account data.\nKept across releases."),
    }),
  )
  assert_true(
    field.annotations.contains({
      key: "moonbit.doc",
      value: Some("Stable identifier."),
    }),
  )
  assert_true(
    enum_annotations.contains({
      key: "moonbit.doc",
      value: Some("Available roles."),
    }),
  )
  assert_true(
    enum_member.annotations.contains({
      key: "moonbit.doc",
      value: Some("Regular member."),
    }),
  )
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

///|
test "parser preserves uuid and container cpp_type metadata" {
  let schema = @moonthrift.parse_idl(
    (
      #|typedef uuid RequestId
      #|typedef map cpp_type "std::unordered_map" <string, i64> Counts
      #|typedef list<string> cpp_type "std::vector" Names
      #|
    ),
  )
  guard schema.definitions
    is [
      Typedef(target=Base(Uuid), ..),
      Typedef(
        target=CppType(Map(Base(String), Base(I64)), "std::unordered_map"),
        ..
      ),
      Typedef(target=CppType(List(Base(String)), "std::vector"), ..),
    ] else {
    fail("expected uuid and cpp_type metadata")
  }
}

///|
test "semantic checker reports structural mistakes" {
  let idl =
    #|typedef Missing Alias
    #|struct Bad { 1: string first, 1: required void first }
    #|union Choice { 1: required string value }
    #|service Api {
    #|  oneway string broken(0: Unknown input) throws (1: Unknown problem)
    #|  void broken()
    #|}
    #|
  let (_, diagnostics) = @moonthrift.compile_idl(idl, source="bad.thrift")
  let codes = diagnostics.map(item => item.code)
  assert_true(codes.contains("MTH102"))
  assert_true(codes.contains("MTH103"))
  assert_true(codes.contains("MTH104"))
  assert_true(codes.contains("MTH105"))
  assert_true(codes.contains("MTH107"))
  assert_true(codes.contains("MTH108"))
  assert_true(codes.contains("MTH109"))
  assert_true(codes.contains("MTH110"))
}

///|
test "well-formed schemas pass semantic checking" {
  let idl =
    #|typedef i64 UserId
    #|struct User { 1: required UserId id, 2: optional string name }
    #|exception Missing { 1: string message }
    #|service Api { User get(1: UserId id) throws (1: Missing missing) }
    #|
  let (_, diagnostics) = @moonthrift.compile_idl(idl)
  assert_eq(diagnostics, [])
}

///|
test "compatibility checker classifies field and enum evolution" {
  let before = @moonthrift.parse_idl(
    "enum Role { USER = 1, ADMIN = 2 } struct User { 1: required i64 id, 2: optional string name }",
  )
  let after = @moonthrift.parse_idl(
    "enum Role { MEMBER = 1, OWNER = 3 } struct User { 1: required string id, 3: optional string email }",
  )
  let changes = @moonthrift.compare_schemas(before, after)
  let codes = changes.map(item => item.code)
  assert_true(codes.contains("MTHC104"))
  assert_true(codes.contains("MTHC103"))
  assert_true(codes.contains("MTHC107"))
  assert_true(codes.contains("MTHC108"))
  assert_true(codes.contains("MTHC109"))
  assert_true(codes.contains("MTHC110"))
  assert_true(@moonthrift.has_breaking_changes(changes))
}

///|
test "compatibility checker recognizes additive service changes" {
  let before = @moonthrift.parse_idl("service Api { void ping() }")
  let after = @moonthrift.parse_idl("service Api { void ping(), i32 status() }")
  let changes = @moonthrift.compare_schemas(before, after)
  assert_eq(changes.length(), 1)
  assert_true(changes[0].kind is Compatible)
  assert_eq(changes[0].code, "MTHC113")
  assert_true(!@moonthrift.has_breaking_changes(changes))
}
