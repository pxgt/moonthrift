///|
fn identity_message(
  message : @protocol.Message,
) -> @protocol.Message raise @protocol.ProtocolError {
  ignore(message.body.require_struct())
  message
}

///|
test "memory transport completes binary and compact request round trips" {
  let protocols : Array[@rpc.RpcProtocol] = [Binary, Compact]
  for wire in protocols {
    let transport = @rpc.MemoryTransport::new(wire, request => {
      let fields = request.body.require_struct()
      let value = @protocol.find_field(fields, 1).unwrap().require_i32()
      {
        name: request.name,
        kind: Reply,
        sequence_id: request.sequence_id,
        body: StructValue([{ id: 0, value: I32Value(value + 1), }]),
      }
    })
    let request : @protocol.Message = {
      name: "Calculator.increment",
      kind: Call,
      sequence_id: 42,
      body: StructValue([{ id: 1, value: I32Value(7), }]),
    }
    let reply = transport.call(request)
    assert_eq(reply.name, request.name)
    assert_eq(reply.sequence_id, 42)
    assert_true(reply.kind is Reply)
    assert_eq(
      @protocol.find_field(reply.body.require_struct(), 0),
      Some(I32Value(8)),
    )
  }
}

///|
test "processor rejects non-call requests and mismatched replies" {
  let request : @protocol.Message = {
    name: "ping",
    kind: Reply,
    sequence_id: 1,
    body: StructValue([]),
  }
  try
    @rpc.process_once(
      Binary,
      @protocol.encode_binary_message(request),
      identity_message,
    )
  catch {
    InvalidMessage(message) => assert_true(message.contains("CALL"))
    _ => fail("unexpected processor error")
  } noraise {
    _ => fail("expected request-type rejection")
  }
  let call : @protocol.Message = { ..request, kind: Call, }
  try
    @rpc.process_once(Compact, @protocol.encode_compact_message(call), message => {
      let reply : @protocol.Message = {
        ..message,
        kind: Reply,
        sequence_id: 2,
      }
      reply
    })
  catch {
    InvalidMessage(message) => assert_true(message.contains("sequence ID"))
    _ => fail("unexpected processor error")
  } noraise {
    _ => fail("expected sequence ID rejection")
  }
}

///|
test "client validates responses from an arbitrary byte transport" {
  let request : @protocol.Message = {
    name: "ping",
    kind: Call,
    sequence_id: 5,
    body: StructValue([]),
  }
  try
    @rpc.call_once(Binary, request, _ => {
      @protocol.encode_binary_message({ ..request, kind: Reply, name: "other", })
    })
  catch {
    InvalidMessage(message) => assert_true(message.contains("method"))
    _ => fail("unexpected client error")
  } noraise {
    _ => fail("expected method rejection")
  }
}

///|
test "legacy processor rejects oneway while exception replies preserve envelope" {
  let request : @protocol.Message = {
    name: "ping",
    kind: Oneway,
    sequence_id: 9,
    body: StructValue([]),
  }
  try
    @rpc.process_once(
      Binary,
      @protocol.encode_binary_message(request),
      identity_message,
    )
  catch {
    InvalidMessage(message) => assert_true(message.contains("CALL"))
    _ => fail("unexpected oneway error")
  } noraise {
    _ => fail("expected oneway rejection")
  }
  let call : @protocol.Message = { ..request, kind: Call, }
  let encoded = @rpc.process_once(
    Compact,
    @protocol.encode_compact_message(call),
    message => {
      let reply : @protocol.Message = { ..message, kind: Exception, }
      reply
    },
  )
  let reply = @protocol.decode_compact_message(encoded)
  assert_true(reply.kind is Exception)
  assert_eq(reply.name, "ping")
  assert_eq(reply.sequence_id, 9)
}

///|
test "optional processor sends no oneway response and requires call replies" {
  let protocols : Array[@rpc.RpcProtocol] = [Binary, Compact]
  for wire in protocols {
    let request : @protocol.Message = {
      name: "emit",
      kind: Oneway,
      sequence_id: 9,
      body: StructValue([]),
    }
    let mut invoked = false
    let result = @rpc.process_once_optional(wire, wire.encode(request), _ => {
      invoked = true
      None
    })
    assert_true(invoked)
    assert_eq(result, None)
    @rpc.send_oneway(wire, request, bytes => {
      @rpc.process_once_optional(wire, bytes, _ => None)
    })
    let call = { ..request, kind: Call, }
    try @rpc.process_once_optional(wire, wire.encode(call), _ => None) catch {
      InvalidMessage(message) => assert_true(message.contains("did not return"))
      _ => fail("unexpected missing-reply error")
    } noraise {
      _ => fail("expected missing CALL reply rejection")
    }
    try
      @rpc.process_once_optional(wire, wire.encode(request), message => {
        Some({ ..message, kind: Reply, })
      })
    catch {
      InvalidMessage(message) => assert_true(message.contains("must not"))
      _ => fail("unexpected oneway reply error")
    } noraise {
      _ => fail("expected ONEWAY reply rejection")
    }
    try @rpc.send_oneway(wire, request, _ => Some(b"unexpected")) catch {
      InvalidMessage(message) =>
        assert_true(message.contains("returned a reply"))
      _ => fail("unexpected oneway transport error")
    } noraise {
      _ => fail("expected unsolicited reply rejection")
    }
    try @rpc.call_once_optional(wire, call, _ => None) catch {
      InvalidMessage(message) => assert_true(message.contains("did not return"))
      _ => fail("unexpected call transport error")
    } noraise {
      _ => fail("expected absent call reply rejection")
    }
  }
}
