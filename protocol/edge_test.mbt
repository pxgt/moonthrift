///|
test "binary scalar variants round-trip signed values and doubles" {
  let values : Array[@protocol.Value] = [
    BoolValue(false),
    ByteValue(-128),
    I16Value(-32768),
    I32Value(-2147483648),
    I64Value(-9223372036854775807L),
    DoubleValue(1.5),
  ]
  for value in values {
    assert_eq(
      @protocol.decode_binary(@protocol.encode_binary(value), value.wire_type()),
      value,
    )
  }
}

///|
test "binary decoder rejects truncated and negative lengths" {
  try @protocol.decode_binary(b"\x00", I16) catch {
    UnexpectedEof(offset=0, needed=2) => ()
    _ => fail("unexpected truncated integer error")
  } noraise {
    _ => fail("expected truncated integer")
  }
  try @protocol.decode_binary(b"\xff\xff\xff\xff", Binary) catch {
    NegativeSize(-1) => ()
    _ => fail("unexpected negative binary length error")
  } noraise {
    _ => fail("expected negative binary length")
  }
  try @protocol.decode_binary(b"\x08\xff\xff\xff\xff", List) catch {
    NegativeSize(-1) => ()
    _ => fail("unexpected negative list length error")
  } noraise {
    _ => fail("expected negative list length")
  }
  try
    @protocol.decode_binary(b"\x08\x00\x00\x00\x02", Set, max_container_size=1)
  catch {
    LimitExceeded(kind="container", limit=1, actual=2) => ()
    _ => fail("unexpected container limit error")
  } noraise {
    _ => fail("expected container limit")
  }
}

///|
test "binary decoder rejects invalid types and excessive depth" {
  try @protocol.decode_binary(b"", Stop) catch {
    TypeMismatch(expected=Struct, actual=Stop) => ()
    _ => fail("unexpected stop error")
  } noraise {
    _ => fail("expected stop type mismatch")
  }
  try @protocol.decode_binary(b"\x7f\x00\x01\x00", Struct) catch {
    InvalidType(0x7f) => ()
    _ => fail("unexpected field type error")
  } noraise {
    _ => fail("expected invalid field type")
  }
  try
    @protocol.decode_binary(
      b"\x08\x00\x01\x00\x00\x00\x00\x00",
      Struct,
      max_depth=0,
    )
  catch {
    LimitExceeded(kind="depth", limit=0, actual=1) => ()
    _ => fail("unexpected depth error")
  } noraise {
    _ => fail("expected depth limit")
  }
}

///|
test "binary encoder rejects mismatched container entries" {
  let value : @protocol.Value = MapValue(key_type=I32, value_type=Bool, entries=[
    (BinaryValue(b"wrong"), BoolValue(true)),
  ])
  try @protocol.encode_binary(value) catch {
    TypeMismatch(expected=I32, actual=Binary) => ()
    _ => fail("unexpected map key error")
  } noraise {
    _ => fail("expected map key mismatch")
  }
  try
    @protocol.encode_binary(
      ListValue(element_type=I32, values=[BoolValue(true)]),
    )
  catch {
    TypeMismatch(expected=I32, actual=Bool) => ()
    _ => fail("unexpected list element error")
  } noraise {
    _ => fail("expected list element mismatch")
  }
}

///|
test "compact scalar and container variants round-trip" {
  let values : Array[@protocol.Value] = [
    BoolValue(false),
    ByteValue(-128),
    I16Value(-32768),
    I32Value(-2147483648),
    I64Value(-9223372036854775807L),
    DoubleValue(1.5),
    SetValue(element_type=Byte, values=[ByteValue(-2)]),
    MapValue(key_type=Stop, value_type=Stop, entries=[]),
  ]
  for value in values {
    assert_eq(
      @protocol.decode_compact(
        @protocol.encode_compact(value),
        value.wire_type(),
      ),
      value,
    )
  }
  let with_false : @protocol.Value = StructValue([
    { id: 1, value: BoolValue(false), },
  ])
  assert_eq(
    @protocol.decode_compact(@protocol.encode_compact(with_false), Struct),
    with_false,
  )
}

///|
test "compact decoder rejects malformed lengths and types" {
  try @protocol.decode_compact(b"", Byte) catch {
    UnexpectedEof(offset=0, needed=1) => ()
    _ => fail("unexpected missing byte error")
  } noraise {
    _ => fail("expected missing byte")
  }
  try @protocol.decode_compact(b"\x02A", Binary, max_binary_size=1) catch {
    LimitExceeded(kind="binary", limit=1, actual=2) => ()
    _ => fail("unexpected binary limit error")
  } noraise {
    _ => fail("expected binary limit")
  }
  try @protocol.decode_compact(b"\x02A", Binary) catch {
    UnexpectedEof(offset=1, needed=2) => ()
    _ => fail("unexpected truncated binary error")
  } noraise {
    _ => fail("expected truncated binary")
  }
  try @protocol.decode_compact(b"\x02\x00", Map, max_container_size=1) catch {
    LimitExceeded(kind="container", limit=1, actual=2) => ()
    _ => fail("unexpected map limit error")
  } noraise {
    _ => fail("expected map limit")
  }
  try @protocol.decode_compact(b"\x1f", List, max_container_size=0) catch {
    LimitExceeded(kind="container", limit=0, actual=1) => ()
    _ => fail("unexpected list limit error")
  } noraise {
    _ => fail("expected list limit")
  }
  try @protocol.decode_compact(b"\x1d\x00", Struct) catch {
    InvalidType(0x0d) => ()
    _ => fail("unexpected compact field type error")
  } noraise {
    _ => fail("expected invalid compact field type")
  }
}

///|
test "compact decoder rejects depth, trailing bytes, and truncated doubles" {
  try @protocol.decode_compact(b"", Stop) catch {
    TypeMismatch(expected=Struct, actual=Stop) => ()
    _ => fail("unexpected stop error")
  } noraise {
    _ => fail("expected stop type mismatch")
  }
  try @protocol.decode_compact(b"\x1c\x00\x00", Struct, max_depth=0) catch {
    LimitExceeded(kind="depth", limit=0, actual=1) => ()
    _ => fail("unexpected depth error")
  } noraise {
    _ => fail("expected depth limit")
  }
  try @protocol.decode_compact(b"\x01\x02", Bool) catch {
    TrailingData(offset=1, remaining=1) => ()
    _ => fail("unexpected trailing data error")
  } noraise {
    _ => fail("expected trailing data")
  }
  try @protocol.decode_compact(b"\x00", Double) catch {
    UnexpectedEof(offset=0, needed=8) => ()
    _ => fail("unexpected truncated double error")
  } noraise {
    _ => fail("expected truncated double")
  }
}

///|
test "compact encoder rejects mismatched container entries" {
  let bad_key : @protocol.Value = MapValue(key_type=I32, value_type=Bool, entries=[
    (BinaryValue(b"wrong"), BoolValue(true)),
  ])
  try @protocol.encode_compact(bad_key) catch {
    TypeMismatch(expected=I32, actual=Binary) => ()
    _ => fail("unexpected map key error")
  } noraise {
    _ => fail("expected map key mismatch")
  }
  let bad_value : @protocol.Value = MapValue(key_type=I32, value_type=Bool, entries=[
    (I32Value(1), BinaryValue(b"wrong")),
  ])
  try @protocol.encode_compact(bad_value) catch {
    TypeMismatch(expected=Bool, actual=Binary) => ()
    _ => fail("unexpected map value error")
  } noraise {
    _ => fail("expected map value mismatch")
  }
  try
    @protocol.encode_compact(
      SetValue(element_type=I32, values=[BoolValue(true)]),
    )
  catch {
    TypeMismatch(expected=I32, actual=Bool) => ()
    _ => fail("unexpected set element error")
  } noraise {
    _ => fail("expected set element mismatch")
  }
}

///|
test "message envelopes reject malformed names, bodies, and suffixes" {
  let non_struct : @protocol.Message = {
    name: "bad",
    kind: Call,
    sequence_id: 0,
    body: I32Value(1),
  }
  try @protocol.encode_binary_message(non_struct) catch {
    TypeMismatch(expected=Struct, actual=I32) => ()
    _ => fail("unexpected binary body error")
  } noraise {
    _ => fail("expected binary body mismatch")
  }
  try @protocol.encode_compact_message(non_struct) catch {
    TypeMismatch(expected=Struct, actual=I32) => ()
    _ => fail("unexpected compact body error")
  } noraise {
    _ => fail("expected compact body mismatch")
  }
  try
    @protocol.decode_binary_message(
      b"\x80\x01\x00\x01\x00\x00\x00\x01\xff\x00\x00\x00\x00\x00",
    )
  catch {
    InvalidMessage(_) => ()
    _ => fail("unexpected binary name error")
  } noraise {
    _ => fail("expected invalid binary name")
  }
  try @protocol.decode_compact_message(b"\x82\x21\x00\x01\xff\x00") catch {
    InvalidMessage(_) => ()
    _ => fail("unexpected compact name error")
  } noraise {
    _ => fail("expected invalid compact name")
  }
  try @protocol.decode_compact_message(b"\x82\x22") catch {
    InvalidMessage(_) => ()
    _ => fail("unexpected compact version error")
  } noraise {
    _ => fail("expected unsupported compact version")
  }
  let valid : @protocol.Message = {
    name: "ok",
    kind: Call,
    sequence_id: 0,
    body: StructValue([]),
  }
  let binary = @protocol.encode_binary_message(valid)
  let compact = @protocol.encode_compact_message(valid)
  try @protocol.decode_binary_message(binary + b"\x00") catch {
    TrailingData(..) => ()
    _ => fail("unexpected binary suffix error")
  } noraise {
    _ => fail("expected binary suffix error")
  }
  try @protocol.decode_compact_message(compact + b"\x00") catch {
    TrailingData(..) => ()
    _ => fail("unexpected compact suffix error")
  } noraise {
    _ => fail("expected compact suffix error")
  }
}

///|
test "typed accessors reject incompatible non-empty containers" {
  let wrong : @protocol.Value = I32Value(1)
  try wrong.require_struct() catch {
    TypeMismatch(expected=Struct, actual=I32) => ()
    _ => fail("unexpected struct accessor error")
  } noraise {
    _ => fail("expected struct accessor mismatch")
  }
  try wrong.require_list(I32) catch {
    TypeMismatch(expected=List, actual=I32) => ()
    _ => fail("unexpected list accessor error")
  } noraise {
    _ => fail("expected list accessor mismatch")
  }
  try wrong.require_set(I32) catch {
    TypeMismatch(expected=Set, actual=I32) => ()
    _ => fail("unexpected set accessor error")
  } noraise {
    _ => fail("expected set accessor mismatch")
  }
  try wrong.require_map(I32, Bool) catch {
    TypeMismatch(expected=Map, actual=I32) => ()
    _ => fail("unexpected map accessor error")
  } noraise {
    _ => fail("expected map accessor mismatch")
  }
  let list : @protocol.Value = ListValue(element_type=Bool, values=[
    BoolValue(true),
  ])
  try list.require_list(I32) catch {
    TypeMismatch(expected=I32, actual=Bool) => ()
    _ => fail("unexpected list type error")
  } noraise {
    _ => fail("expected list element mismatch")
  }
  let set : @protocol.Value = SetValue(element_type=Bool, values=[
    BoolValue(true),
  ])
  try set.require_set(I32) catch {
    TypeMismatch(expected=I32, actual=Bool) => ()
    _ => fail("unexpected set type error")
  } noraise {
    _ => fail("expected set element mismatch")
  }
  let map : @protocol.Value = MapValue(key_type=I32, value_type=Bool, entries=[
    (I32Value(1), BoolValue(true)),
  ])
  try map.require_map(Binary, Bool) catch {
    TypeMismatch(expected=Binary, actual=I32) => ()
    _ => fail("unexpected map key type error")
  } noraise {
    _ => fail("expected map key mismatch")
  }
  try map.require_map(I32, Binary) catch {
    TypeMismatch(expected=Binary, actual=Bool) => ()
    _ => fail("unexpected map value type error")
  } noraise {
    _ => fail("expected map value mismatch")
  }
}
