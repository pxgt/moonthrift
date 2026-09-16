///|
test "binary protocol matches a known struct fixture" {
  let value : @protocol.Value = StructValue([
    { id: 1, value: I32Value(42), },
    { id: 2, value: BinaryValue(b"Ada"), },
    { id: 3, value: BoolValue(true), },
  ])
  let encoded = @protocol.encode_binary(value)
  assert_eq(
    encoded, b"\x08\x00\x01\x00\x00\x00\x2a\x0b\x00\x02\x00\x00\x00\x03Ada\x02\x00\x03\x01\x00",
  )
  assert_eq(@protocol.decode_binary(encoded, Struct), value)
}

///|
test "binary protocol round-trips nested containers" {
  let value : @protocol.Value = MapValue(key_type=Binary, value_type=List, entries=[
    (
      BinaryValue(b"scores"),
      ListValue(element_type=I64, values=[
        I64Value(-1L),
        I64Value(9007199254740991L),
      ]),
    ),
  ])
  let encoded = @protocol.encode_binary(value)
  assert_eq(@protocol.decode_binary(encoded, Map), value)
}

///|
test "binary decoder enforces size and trailing-data limits" {
  try
    @protocol.decode_binary(b"\x00\x00\x00\x05hello", Binary, max_binary_size=4)
  catch {
    LimitExceeded(kind="binary", limit=4, actual=5) => ()
    _ => fail("unexpected size error")
  } noraise {
    _ => fail("expected size limit")
  }
  try @protocol.decode_binary(b"\x01\x00", Bool) catch {
    TrailingData(offset=1, remaining=1) => ()
    _ => fail("unexpected trailing-data error")
  } noraise {
    _ => fail("expected trailing-data error")
  }
}
