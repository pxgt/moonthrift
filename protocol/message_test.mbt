///|
test "binary message envelope matches strict protocol bytes" {
  let message : @protocol.Message = {
    name: "ping",
    kind: Call,
    sequence_id: 7,
    body: StructValue([]),
  }
  let encoded = @protocol.encode_binary_message(message)
  assert_eq(
    encoded, b"\x80\x01\x00\x01\x00\x00\x00\x04ping\x00\x00\x00\x07\x00",
  )
  assert_eq(@protocol.decode_binary_message(encoded), message)
}

///|
test "compact message envelope round-trips unicode name and body" {
  let message : @protocol.Message = {
    name: "查找",
    kind: Reply,
    sequence_id: 300,
    body: StructValue([{ id: 1, value: I32Value(9), }]),
  }
  let encoded = @protocol.encode_compact_message(message)
  assert_eq(encoded[0], b'\x82')
  assert_eq(@protocol.decode_compact_message(encoded), message)
}

///|
test "message decoder rejects wrong protocol headers" {
  try @protocol.decode_binary_message(b"\x00\x00\x00\x00") catch {
    InvalidMessage(_) => ()
    _ => fail("unexpected binary message error")
  } noraise {
    _ => fail("expected invalid binary header")
  }
  try @protocol.decode_compact_message(b"\x81\x21") catch {
    InvalidMessage(_) => ()
    _ => fail("unexpected compact message error")
  } noraise {
    _ => fail("expected invalid compact header")
  }
}
