///|
test "generated mixed service sends oneway without a response on both codecs" {
  let protocols : Array[@rpc.RpcProtocol] = [Binary, Compact]
  for wire in protocols {
    let observed : Array[Int] = []
    let sequences : Array[Int] = []
    let handler : @generated_oneway.EventsHandler = {
      emit: args => observed.push(args.value),
      ping: args => Success(args.value + 1),
    }
    let client = @generated_oneway.EventsClient::new(wire, bytes => {
      sequences.push(wire.decode(bytes).sequence_id)
      handler.serve_once(wire, bytes)
    })
    client.emit({ value: 7, })
    assert_eq(observed, [7])
    let reply = client.ping({ value: 9, })
    assert_eq(reply, Success(10))
    assert_eq(sequences, [1, 2])
    let bad : @protocol.Message = {
      name: "missing",
      kind: Call,
      sequence_id: 42,
      body: StructValue([]),
    }
    let response = handler.process(bad)
    match response {
      Some(message) => {
        assert_true(message.kind is Exception)
        assert_eq(message.sequence_id, 42)
        assert_eq(
          @rpc.ApplicationException::from_thrift_value(message.body).type_code,
          1,
        )
      }
      None => fail("expected unknown-method reply")
    }
    assert_eq(handler.process({ ..bad, kind: Oneway, }), None)
    let invalid_call = handler.process({ ..bad, name: "emit", })
    match invalid_call {
      Some(message) =>
        assert_eq(
          @rpc.ApplicationException::from_thrift_value(message.body).type_code,
          2,
        )
      None => fail("expected invalid-message-type reply")
    }
  }
}
