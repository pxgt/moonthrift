///|
fn verify_published_package() -> String raise {
  let idl =
    #|struct User {
    #|  1: required i64 id
    #|}
    #|
  let (schema, diagnostics) = @moonthrift.compile_idl(idl)
  if schema.definitions.length() != 1 || !diagnostics.is_empty() {
    fail("published parser did not accept the example IDL")
  }
  let value : @protocol.Value = StructValue([{ id: 1, value: I64Value(7L), }])
  let binary = @protocol.encode_binary(value)
  let compact = @protocol.encode_compact(value)
  if @protocol.decode_binary(binary, Struct) != value ||
    @protocol.decode_compact(compact, Struct) != value {
    fail("published codecs did not round-trip")
  }
  "Mooncakes 0.3.0: parsed 1 definition; Binary and Compact round trips passed"
}

///|
fn main raise {
  println(verify_published_package())
}
