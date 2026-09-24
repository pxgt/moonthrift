///|
test "framed codec uses signed big-endian length and exact payload" {
  assert_eq(@rpc.encode_frame(b"abc"), b"\x00\x00\x00\x03abc")
  assert_eq(@rpc.decode_frame(b"\x00\x00\x00\x03abc"), b"abc")
  assert_eq(@rpc.encode_frame(b""), b"\x00\x00\x00\x00")
  assert_eq(@rpc.decode_frame(b"\x00\x00\x00\x00"), b"")
  assert_eq(@rpc.default_max_frame_size, 16384000)
}

///|
test "framed codec rejects negative, oversized, truncated, and trailing data" {
  try @rpc.decode_frame(b"\xff\xff\xff\xff") catch {
    NegativeSize(-1) => ()
    _ => fail("expected negative frame length")
  } noraise {
    _ => fail("expected negative frame rejection")
  }
  try @rpc.decode_frame(b"\x00\xfa\x00\x01") catch {
    LimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "frame")
      assert_eq(limit, 16384000)
      assert_eq(actual, 16384001)
    }
    _ => fail("expected oversized frame length")
  } noraise {
    _ => fail("expected oversized frame rejection")
  }
  try @rpc.decode_frame(b"\x00\x00\x00") catch {
    UnexpectedEof(offset~, needed~) => {
      assert_eq(offset, 0)
      assert_eq(needed, 4)
    }
    _ => fail("expected incomplete header")
  } noraise {
    _ => fail("expected incomplete header rejection")
  }
  try @rpc.decode_frame(b"\x00\x00\x00\x03ab") catch {
    UnexpectedEof(offset~, needed~) => {
      assert_eq(offset, 4)
      assert_eq(needed, 3)
    }
    _ => fail("expected incomplete body")
  } noraise {
    _ => fail("expected incomplete body rejection")
  }
  try @rpc.decode_frame(b"\x00\x00\x00\x01ab") catch {
    TrailingData(offset~, remaining~) => {
      assert_eq(offset, 5)
      assert_eq(remaining, 1)
    }
    _ => fail("expected trailing-data error")
  } noraise {
    _ => fail("expected trailing-data rejection")
  }
  try @rpc.encode_frame(b"abc", max_frame_size=2) catch {
    LimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "frame")
      assert_eq(limit, 2)
      assert_eq(actual, 3)
    }
    _ => fail("expected custom-limit error")
  } noraise {
    _ => fail("expected custom-limit rejection")
  }
  try @rpc.FrameDecoder::new(max_frame_size=16384001) catch {
    InvalidValue(_) => ()
    _ => fail("expected invalid limit")
  } noraise {
    _ => fail("expected limit validation")
  }
}

///|
test "stream decoder tolerates every split and coalesced frames" {
  let bytes = @rpc.encode_frame(b"abc")
  for split in 0..<=bytes.length() {
    let decoder = @rpc.FrameDecoder::new()
    let first = decoder.push(bytes[:split].to_owned())
    let second = decoder.push(bytes[split:].to_owned())
    assert_eq(first.length() + second.length(), 1)
    if first.length() == 1 {
      assert_eq(first[0], b"abc")
    } else {
      assert_eq(second[0], b"abc")
    }
    assert_true(!decoder.has_pending())
  }
  let decoder = @rpc.FrameDecoder::new()
  assert_eq(decoder.push(b"\x00\x00"), [])
  assert_true(decoder.has_pending())
  assert_eq(decoder.push(b"\x00\x00"), [b""])
  assert_true(!decoder.has_pending())
  let joined = @rpc.encode_frame(b"a") +
    @rpc.encode_frame(b"") +
    @rpc.encode_frame(b"xyz")
  assert_eq(decoder.push(joined), [b"a", b"", b"xyz"])
  let decoder = @rpc.FrameDecoder::new()
  let emitted : Array[Bytes] = []
  for index in 0..<joined.length() {
    for frame in decoder.push(joined[index:index + 1].to_owned()) {
      emitted.push(frame)
    }
  }
  assert_eq(emitted, [b"a", b"", b"xyz"])
  assert_true(!decoder.has_pending())
}

///|
test "stream decoder resets after invalid length" {
  let decoder = @rpc.FrameDecoder::new(max_frame_size=2)
  try decoder.push(b"\x00\x00\x00\x03") catch {
    LimitExceeded(kind~, limit~, actual~) => {
      assert_eq(kind, "frame")
      assert_eq(limit, 2)
      assert_eq(actual, 3)
    }
    _ => fail("expected frame limit error")
  } noraise {
    _ => fail("expected oversized frame rejection")
  }
  assert_true(!decoder.has_pending())
  assert_eq(decoder.push(@rpc.encode_frame(b"ok")), [b"ok"])
}

///|
test "framed RPC composes with Binary, Compact, and oneway dispatch" {
  let protocols : Array[@rpc.RpcProtocol] = [Binary, Compact]
  for wire in protocols {
    let request : @protocol.Message = {
      name: "increment",
      kind: Call,
      sequence_id: 17,
      body: StructValue([{ id: 1, value: I32Value(7), }]),
    }
    let reply = @rpc.call_once(wire, request, payload => {
      let framed_request = @rpc.encode_frame(payload)
      let decoded_request = @rpc.decode_frame(framed_request)
      let response = @rpc.process_once(wire, decoded_request, incoming => {
        let value = @protocol.find_field(incoming.body.require_struct(), 1)
          .unwrap()
          .require_i32()
        {
          name: incoming.name,
          kind: Reply,
          sequence_id: incoming.sequence_id,
          body: StructValue([{ id: 0, value: I32Value(value + 1), }]),
        }
      })
      @rpc.decode_frame(@rpc.encode_frame(response))
    })
    assert_eq(reply.sequence_id, 17)
    assert_eq(
      @protocol.find_field(reply.body.require_struct(), 0),
      Some(I32Value(8)),
    )
    let oneway = { ..request, kind: Oneway, }
    let mut called = false
    @rpc.send_oneway(wire, oneway, payload => {
      let framed = @rpc.encode_frame(payload)
      let response = @rpc.process_once_optional(
        wire,
        @rpc.decode_frame(framed),
        _ => {
          called = true
          None
        },
      )
      response.map(bytes => @rpc.encode_frame(bytes))
    })
    assert_true(called)
  }
}
