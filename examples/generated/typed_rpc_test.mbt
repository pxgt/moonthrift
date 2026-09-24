///|
fn test_get_user(
  args : @generated.UserDirectoryGetUserArgs,
) -> @generated.UserDirectoryGetUserResult raise @protocol.ProtocolError {
  if args.id < 0L {
    raise InvalidMessage("negative user id")
  }
  if args.id == 7L {
    Success({
      id: 7L,
      name: "Ada",
      role: None,
      aliases: None,
      scores: None,
      flags: None,
      revision: 1,
    })
  } else {
    Missing({ id: args.id, message: "not found", })
  }
}

///|
fn test_list_users(
  args : @generated.UserDirectoryListUsersArgs,
) -> @generated.UserDirectoryListUsersResult raise @protocol.ProtocolError {
  ignore(
    @generated.UserDirectoryListUsersArgs::from_thrift_value(
      args.to_thrift_value(),
    ),
  )
  Success([])
}

///|
test "generated typed client and handler route methods on both protocols" {
  let handler : @generated.UserDirectoryHandler = {
    get_user: test_get_user,
    list_users: test_list_users,
  }
  let protocols : Array[@rpc.RpcProtocol] = [Binary, Compact]
  for wire in protocols {
    let sequences : Array[Int] = []
    let client = @generated.UserDirectoryClient::new(wire, bytes => {
      let request = wire.decode(bytes)
      sequences.push(request.sequence_id)
      handler.serve_once(wire, bytes)
    })
    let found = client.get_user({ id: 7L, })
    match found {
      Success(user) => assert_eq(user.name, "Ada")
      _ => fail("expected successful get_user result")
    }
    let missing = client.get_user({ id: 9L, })
    match missing {
      Missing(value) => assert_eq(value.id, 9L)
      _ => fail("expected declared missing-user result")
    }
    let listed = client.list_users(
      @generated.UserDirectoryListUsersArgs::from_thrift_value(StructValue([])),
    )
    match listed {
      Success(users) => assert_eq(users.length(), 0)
    }
    assert_eq(sequences, [1, 2, 3])
  }
}

///|
test "generated handler returns a standard unknown-method exception" {
  let handler : @generated.UserDirectoryHandler = {
    get_user: test_get_user,
    list_users: test_list_users,
  }
  let request : @protocol.Message = {
    name: "unknown",
    kind: Call,
    sequence_id: 1,
    body: StructValue([]),
  }
  let reply = handler.process(request)
  assert_true(reply.kind is Exception)
  assert_eq(reply.sequence_id, 1)
  let exception = @rpc.ApplicationException::from_thrift_value(reply.body)
  assert_eq(exception.type_code, 1)
  assert_true(exception.message.contains("unknown"))
}

///|
test "generated client decodes an application exception envelope" {
  let client = @generated.UserDirectoryClient::new(Binary, bytes => {
    let request = @protocol.decode_binary_message(bytes)
    let reply = @rpc.application_exception_reply(request, 6, "handler failed")
    @protocol.encode_binary_message(reply)
  })
  try client.get_user({ id: 7L, }) catch {
    ApplicationException(message~, type_code~) => {
      assert_eq(message, "handler failed")
      assert_eq(type_code, 6)
    }
    _ => fail("unexpected client error")
  } noraise {
    _ => fail("expected application-exception rejection")
  }
}

///|
test "generated handler converts bad arguments and callback failures" {
  let handler : @generated.UserDirectoryHandler = {
    get_user: test_get_user,
    list_users: test_list_users,
  }
  let request : @protocol.Message = {
    name: "get_user",
    kind: Call,
    sequence_id: 12,
    body: StructValue([]),
  }
  let invalid = handler.process(request)
  assert_true(invalid.kind is Exception)
  assert_eq(
    @rpc.ApplicationException::from_thrift_value(invalid.body).type_code,
    7,
  )
  let failing = handler.process({
    ..request,
    body: @generated.UserDirectoryGetUserArgs::{ id: -1L, }.to_thrift_value(),
  })
  assert_true(failing.kind is Exception)
  assert_eq(
    @rpc.ApplicationException::from_thrift_value(failing.body).type_code,
    6,
  )
}
