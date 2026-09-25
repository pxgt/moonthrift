///|
// Fixed-seed generator: a failing case is reproducible on every backend.
struct WireTestRng {
  mut state : UInt
}

///|
fn WireTestRng::next(self : WireTestRng) -> UInt {
  self.state = self.state * 1664525U + 1013904223U
  self.state
}

///|
fn WireTestRng::choose(self : WireTestRng, upper : Int) -> Int {
  (self.next() % upper.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn WireTestRng::bytes(self : WireTestRng, maximum : Int) -> Bytes {
  let items : Array[Byte] = []
  for _ in 0..<self.choose(maximum + 1) {
    items.push(self.next().to_byte())
  }
  Bytes::from_array(items)
}

///|
fn generated_value(rng : WireTestRng, depth : Int) -> @protocol.Value {
  let variant = rng.choose(if depth == 0 { 7 } else { 11 })
  match variant {
    0 => BoolValue(rng.choose(2) == 1)
    1 => ByteValue(rng.choose(256) - 128)
    2 => I16Value(rng.choose(65536) - 32768)
    3 => I32Value(rng.next().reinterpret_as_int())
    4 => I64Value(rng.next().to_int64() - 2147483648L)
    5 => DoubleValue((rng.choose(2000) - 1000).to_double() / 4.0)
    6 => BinaryValue(rng.bytes(16))
    7 => {
      let fields : Array[@protocol.FieldValue] = []
      for index in 0..<rng.choose(4) {
        fields.push({ id: index + 1, value: generated_value(rng, depth - 1), })
      }
      StructValue(fields)
    }
    8 => {
      let values : Array[@protocol.Value] = []
      for _ in 0..<rng.choose(5) {
        values.push(I32Value(rng.next().reinterpret_as_int()))
      }
      ListValue(element_type=I32, values~)
    }
    9 => {
      let values : Array[@protocol.Value] = []
      for _ in 0..<rng.choose(5) {
        values.push(BinaryValue(rng.bytes(8)))
      }
      SetValue(element_type=Binary, values~)
    }
    _ => {
      let entries : Array[(@protocol.Value, @protocol.Value)] = []
      for _ in 0..<rng.choose(5) {
        entries.push(
          (BinaryValue(rng.bytes(8)), I64Value(rng.next().to_int64())),
        )
      }
      if entries.length() == 0 {
        // Thrift Compact does not put key/value type IDs on the wire for
        // empty maps; the decoder represents those absent IDs as Stop.
        MapValue(key_type=Stop, value_type=Stop, entries~)
      } else {
        MapValue(key_type=Binary, value_type=I64, entries~)
      }
    }
  }
}

///|
test "fixed-seed nested values round-trip through both wire protocols" {
  let rng : WireTestRng = { state: 0x4d544852U, }
  for case_index in 0..<512 {
    let value = generated_value(rng, 3)
    let binary = @protocol.encode_binary(value)
    let compact = @protocol.encode_compact(value)
    let binary_value = @protocol.decode_binary(binary, value.wire_type())
    let compact_value = @protocol.decode_compact(compact, value.wire_type())
    if binary_value != value {
      fail("binary round-trip failed at case \{case_index}")
    }
    if compact_value != value {
      fail(
        "compact round-trip failed at case \{case_index}: expected \{Repr(value)}, actual \{Repr(compact_value)}",
      )
    }
    assert_eq(@protocol.encode_binary(binary_value), binary)
    assert_eq(@protocol.encode_compact(compact_value), compact)
  }
}

///|
test "every proper prefix of a valid RPC envelope is rejected" {
  let message : @protocol.Message = {
    name: "lookup",
    kind: Call,
    sequence_id: 98765,
    body: StructValue([
      { id: 1, value: BinaryValue(b"moon"), },
      { id: 2, value: ListValue(element_type=I32, values=[I32Value(1)]), },
    ]),
  }
  let binary = @protocol.encode_binary_message(message)
  let compact = @protocol.encode_compact_message(message)
  for length in 0..<binary.length() {
    try @protocol.decode_binary_message(binary[:length].to_owned()) catch {
      _ => ()
    } noraise {
      _ => fail("binary prefix \{length} was accepted")
    }
  }
  for length in 0..<compact.length() {
    try @protocol.decode_compact_message(compact[:length].to_owned()) catch {
      _ => ()
    } noraise {
      _ => fail("compact prefix \{length} was accepted")
    }
  }
}

///|
test "bounded malformed byte corpus is rejected or canonicalizes stably" {
  let rng : WireTestRng = { state: 0x46555a5aU, }
  let mut binary_accepted = 0
  let mut binary_rejected = 0
  let mut compact_accepted = 0
  let mut compact_rejected = 0
  for case_index in 0..<1024 {
    let input = rng.bytes(64)
    let ty : @protocol.WireType = match rng.choose(7) {
      0 => Struct
      1 => Map
      2 => List
      3 => Set
      4 => Binary
      5 => I64
      _ => Bool
    }
    try
      @protocol.decode_binary(
        input,
        ty,
        max_depth=4,
        max_container_size=8,
        max_binary_size=32,
      )
    catch {
      _ => binary_rejected += 1
    } noraise {
      value => {
        binary_accepted += 1
        let canonical = @protocol.encode_binary(value)
        let decoded = @protocol.decode_binary(
          canonical,
          ty,
          max_depth=4,
          max_container_size=8,
          max_binary_size=32,
        )
        if @protocol.encode_binary(decoded) != canonical {
          fail("binary canonicalization failed at case \{case_index}")
        }
      }
    }
    try
      @protocol.decode_compact(
        input,
        ty,
        max_depth=4,
        max_container_size=8,
        max_binary_size=32,
      )
    catch {
      _ => compact_rejected += 1
    } noraise {
      value => {
        compact_accepted += 1
        let canonical = @protocol.encode_compact(value)
        let decoded = @protocol.decode_compact(
          canonical,
          ty,
          max_depth=4,
          max_container_size=8,
          max_binary_size=32,
        )
        if @protocol.encode_compact(decoded) != canonical {
          fail("compact canonicalization failed at case \{case_index}")
        }
      }
    }
  }
  assert_true(binary_accepted > 0 && binary_rejected > 0)
  assert_true(compact_accepted > 0 && compact_rejected > 0)
}
