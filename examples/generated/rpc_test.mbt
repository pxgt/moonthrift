///|
test "generated service models cross the in-memory RPC byte boundary" {
  let protocols : Array[@rpc.RpcProtocol] = [Binary, Compact]
  for wire in protocols {
    let transport = @rpc.MemoryTransport::new(wire, request => {
      let args = @generated.UserDirectoryGetUserArgs::from_thrift_value(
        request.body,
      )
      let result : @generated.UserDirectoryGetUserResult = if args.id == 7L {
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
      {
        name: request.name,
        kind: Reply,
        sequence_id: request.sequence_id,
        body: result.to_thrift_value(),
      }
    })
    for id in [7L, 9L] {
      let args : @generated.UserDirectoryGetUserArgs = { id, }
      let request : @protocol.Message = {
        name: "get_user",
        kind: Call,
        sequence_id: id.to_int(),
        body: args.to_thrift_value(),
      }
      let reply = transport.call(request)
      let result = @generated.UserDirectoryGetUserResult::from_thrift_value(
        reply.body,
      )
      match result {
        Success(user) => {
          assert_eq(id, 7L)
          assert_eq(user.name, "Ada")
        }
        Missing(missing) => {
          assert_eq(id, 9L)
          assert_eq(missing.id, 9L)
        }
      }
    }
  }
}
