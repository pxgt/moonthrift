///|
test "application exception body and envelope round-trip on both protocols" {
  let protocols : Array[@rpc.RpcProtocol] = [Binary, Compact]
  for wire in protocols {
    let request : @protocol.Message = {
      name: "missing",
      kind: Call,
      sequence_id: 41,
      body: StructValue([]),
    }
    let encoded = wire.encode(
      @rpc.application_exception_reply(request, 1, "unknown method missing"),
    )
    let reply = wire.decode(encoded)
    assert_true(reply.kind is Exception)
    assert_eq(reply.name, "missing")
    assert_eq(reply.sequence_id, 41)
    let exception = @rpc.ApplicationException::from_thrift_value(reply.body)
    assert_eq(exception.message, "unknown method missing")
    assert_eq(exception.type_code, 1)
    try @rpc.reply_result_body(reply) catch {
      ApplicationException(message~, type_code~) => {
        assert_eq(message, "unknown method missing")
        assert_eq(type_code, 1)
      }
      _ => fail("unexpected remote error")
    } noraise {
      _ => fail("expected remote application exception")
    }
  }
}

///|
test "application exception defaults and unknown numeric codes are preserved" {
  let empty = @rpc.ApplicationException::from_thrift_value(StructValue([]))
  assert_eq(empty.message, "")
  assert_eq(empty.type_code, 0)
  let unknown : @rpc.ApplicationException = {
    message: "new peer",
    type_code: 12345,
  }
  assert_eq(
    @rpc.ApplicationException::from_thrift_value(unknown.to_thrift_value()),
    unknown,
  )
  try
    @rpc.ApplicationException::from_thrift_value(
      StructValue([{ id: 2, value: @protocol.string_value("wrong"), }]),
    )
  catch {
    TypeMismatch(..) => ()
    _ => fail("expected type rejection")
  } noraise {
    _ => fail("expected malformed exception rejection")
  }
}
