///|
// Deterministic mutations of valid documents reach lexer, parser, and
// semantic paths without relying on an external fuzzing runtime.
struct IdlTestRng {
  mut state : UInt
}

///|
fn IdlTestRng::choose(self : IdlTestRng, upper : Int) -> Int {
  self.state = self.state * 1664525U + 1013904223U
  (self.state % upper.reinterpret_as_uint()).reinterpret_as_int()
}

///|
test "fixed-seed malformed IDL corpus produces schemas or typed errors" {
  let rng : IdlTestRng = { state: 0x49444c46U, }
  let mut parsed = 0
  let mut rejected = 0
  let documents = [
    "struct User { 1: required i64 id, 2: optional string name }", "enum Role { USER = 1, ADMIN = 2 }",
    "service Api { i32 get(1: list<string> names) throws (1: Fault error) }", "typedef map<string, list<i32>> Index",
    "const string label = \"moon\\nbit\"", "include \"common.thrift\"\nstruct Request { 1: required common.User user }",
  ]
  let glyphs = [
    "{", "}", "<", ">", "\"", "'", "/", "*", "0", "-", "(", ")", "@", "\n", " ",
  ]
  for case_index in 0..<768 {
    let original = documents[rng.choose(documents.length())]
    let at = rng.choose(original.length())
    let glyph = glyphs[rng.choose(glyphs.length())]
    let prefix = original[:at].to_owned()
    let suffix = original[at + 1:].to_owned()
    let input = match rng.choose(3) {
      0 => prefix + suffix
      1 => prefix + glyph + suffix
      _ => prefix + glyph + original[at:].to_owned()
    }
    try @moonthrift.parse_idl(input, source="fuzz.thrift") catch {
      _ => rejected += 1
    } noraise {
      schema => {
        parsed += 1
        let again = @moonthrift.parse_idl(input, source="fuzz.thrift")
        if schema != again {
          fail("IDL parse was not deterministic at case \{case_index}")
        }
        ignore(@moonthrift.check_schema(schema))
      }
    }
  }
  assert_true(parsed > 0 && rejected > 0)
}
