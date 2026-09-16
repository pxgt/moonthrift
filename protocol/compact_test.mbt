///|
test "compact protocol matches a known struct fixture" {
  let value : @protocol.Value = StructValue([
    { id: 1, value: I32Value(42), },
    { id: 2, value: BinaryValue(b"Ada"), },
    { id: 3, value: BoolValue(true), },
  ])
  let encoded = @protocol.encode_compact(value)
  assert_eq(encoded, b"\x15\x54\x18\x03Ada\x11\x00")
  assert_eq(@protocol.decode_compact(encoded, Struct), value)
}

///|
test "compact protocol round-trips nested values and large lists" {
  let values : Array[@protocol.Value] = []
  for value in 0..<20 {
    values.push(I16Value(value - 10))
  }
  let dynamic : @protocol.Value = StructValue([
    { id: 20, value: ListValue(element_type=I16, values~), },
    {
      id: 21,
      value: MapValue(key_type=Binary, value_type=Bool, entries=[
        (BinaryValue(b"enabled"), BoolValue(false)),
      ]),
    },
  ])
  let encoded = @protocol.encode_compact(dynamic)
  assert_eq(@protocol.decode_compact(encoded, Struct), dynamic)
}

///|
test "compact decoder rejects malformed booleans and varints" {
  try @protocol.decode_compact(b"\x03", Bool) catch {
    InvalidCompact(_) => ()
    _ => fail("unexpected boolean error")
  } noraise {
    _ => fail("expected invalid boolean")
  }
  try
    @protocol.decode_compact(
      b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80",
      I64,
    )
  catch {
    InvalidCompact(_) => ()
    _ => fail("unexpected varint error")
  } noraise {
    _ => fail("expected oversized varint")
  }
}
