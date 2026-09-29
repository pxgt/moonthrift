///|
// Fixed bytes produced by Apache Thrift Python 0.24.0 for a struct whose
// field 1 is the uuid 00112233-4455-6677-8899-aabbccddeeff and whose field 2
// is a one-element list<uuid>. The pinned interop/python environment
// reproduces them; see docs/protocols.md ("UUID wire format").
let apache_uuid_binary : Bytes = b"\x10\x00\x01\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff\x0f\x00\x02\x10\x00\x00\x00\x01\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff\x00"

///|
let apache_uuid_compact : Bytes = b"\x1d\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff\x19\x1d\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff\x00"

///|
let sample_uuid : Bytes = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff"

///|
fn apache_uuid_value() -> @protocol.Value {
  StructValue([
    { id: 1, value: UuidValue(sample_uuid), },
    {
      id: 2,
      value: ListValue(element_type=Uuid, values=[UuidValue(sample_uuid)]),
    },
  ])
}

///|
test "uuid wire type ids follow Apache Thrift" {
  assert_eq(@protocol.WireType::Uuid.binary_id(), 16)
  assert_eq(@protocol.WireType::from_binary_id(16), Uuid)
  assert_eq(@protocol.UuidValue(sample_uuid).wire_type(), Uuid)
}

///|
test "binary uuid matches Apache Thrift Python bytes" {
  let value = apache_uuid_value()
  assert_eq(@protocol.encode_binary(value), apache_uuid_binary)
  assert_eq(@protocol.decode_binary(apache_uuid_binary, Struct), value)
}

///|
test "compact uuid matches Apache Thrift Python bytes" {
  let value = apache_uuid_value()
  assert_eq(@protocol.encode_compact(value), apache_uuid_compact)
  assert_eq(@protocol.decode_compact(apache_uuid_compact, Struct), value)
}

///|
test "uuid inside set and map round-trips in both protocols" {
  let other : Bytes = b"\xff\xee\xdd\xcc\xbb\xaa\x99\x88\x77\x66\x55\x44\x33\x22\x11\x00"
  let values : Array[@protocol.Value] = [
    SetValue(element_type=Uuid, values=[
      UuidValue(sample_uuid),
      UuidValue(other),
    ]),
    MapValue(key_type=Uuid, value_type=Uuid, entries=[
      (UuidValue(sample_uuid), UuidValue(other)),
    ]),
    MapValue(key_type=I32, value_type=Uuid, entries=[
      (I32Value(1), UuidValue(sample_uuid)),
    ]),
  ]
  for value in values {
    assert_eq(
      @protocol.decode_binary(@protocol.encode_binary(value), value.wire_type()),
      value,
    )
    assert_eq(
      @protocol.decode_compact(
        @protocol.encode_compact(value),
        value.wire_type(),
      ),
      value,
    )
  }
}

///|
test "uuid encoders reject payloads that are not exactly 16 bytes" {
  for size in [0, 15, 17] {
    let payload = Bytes::from_array(Array::make(size, b'\x01'))
    let expected = "uuid must be exactly 16 bytes, got \{size}"
    try @protocol.encode_binary(UuidValue(payload)) catch {
      InvalidValue(message) => assert_eq(message, expected)
      _ => fail("unexpected binary uuid error")
    } noraise {
      _ => fail("binary encoder accepted a \{size}-byte uuid")
    }
    try @protocol.encode_compact(UuidValue(payload)) catch {
      InvalidValue(message) => assert_eq(message, expected)
      _ => fail("unexpected compact uuid error")
    } noraise {
      _ => fail("compact encoder accepted a \{size}-byte uuid")
    }
  }
}

///|
test "truncated uuid input reports UnexpectedEof" {
  for length in 0..<16 {
    let binary = apache_uuid_binary[:3 + length].to_owned()
    try @protocol.decode_binary(binary, Struct) catch {
      UnexpectedEof(..) => ()
      _ => fail("unexpected binary error at length \{length}")
    } noraise {
      _ => fail("binary decoder accepted a truncated uuid")
    }
    let compact = apache_uuid_compact[:1 + length].to_owned()
    try @protocol.decode_compact(compact, Struct) catch {
      UnexpectedEof(..) => ()
      _ => fail("unexpected compact error at length \{length}")
    } noraise {
      _ => fail("compact decoder accepted a truncated uuid")
    }
  }
  try @protocol.decode_binary(sample_uuid[:15].to_owned(), Uuid) catch {
    UnexpectedEof(offset=0, needed=16) => ()
    _ => fail("unexpected top-level binary error")
  } noraise {
    _ => fail("top-level binary uuid was accepted")
  }
  try @protocol.decode_compact(sample_uuid[:15].to_owned(), Uuid) catch {
    UnexpectedEof(offset=0, needed=16) => ()
    _ => fail("unexpected top-level compact error")
  } noraise {
    _ => fail("top-level compact uuid was accepted")
  }
}

///|
test "require_uuid accepts uuid and legacy 16-byte binary values" {
  assert_eq(@protocol.UuidValue(sample_uuid).require_uuid(), sample_uuid)
  assert_eq(@protocol.BinaryValue(sample_uuid).require_uuid(), sample_uuid)
}

///|
test "require_uuid rejects wrong lengths and other types" {
  try @protocol.BinaryValue(b"\x01\x02\x03").require_uuid() catch {
    InvalidValue(_) => ()
    _ => fail("unexpected short binary error")
  } noraise {
    _ => fail("3-byte binary was accepted as a uuid")
  }
  try @protocol.UuidValue(b"\x01\x02\x03").require_uuid() catch {
    InvalidValue(_) => ()
    _ => fail("unexpected short uuid error")
  } noraise {
    _ => fail("3-byte uuid value was accepted")
  }
  try @protocol.I32Value(1).require_uuid() catch {
    TypeMismatch(expected=Uuid, actual=I32) => ()
    _ => fail("unexpected type mismatch")
  } noraise {
    _ => fail("an i32 was accepted as a uuid")
  }
}

///|
test "legacy binary-encoded uuid is still readable through require_uuid" {
  // MoonThrift <= 0.3.1 wrote uuid as a length-prefixed binary field.
  let legacy = @protocol.encode_binary(
    StructValue([{ id: 1, value: BinaryValue(sample_uuid), }]),
  )
  let fields = @protocol.decode_binary(legacy, Struct).require_struct()
  assert_eq(fields[0].value.require_uuid(), sample_uuid)
}
