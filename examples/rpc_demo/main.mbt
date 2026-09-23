///|
fn main raise {
  let transport = @rpc.MemoryTransport::new(Compact, request => {
    let args = @model.UserDirectoryGetUserArgs::from_thrift_value(request.body)
    let user : @model.User = {
      id: args.id,
      name: "Ada",
      role: None,
      aliases: None,
      scores: None,
      flags: None,
      revision: 1,
    }
    let result : @model.UserDirectoryGetUserResult = Success(user)
    {
      name: request.name,
      kind: Reply,
      sequence_id: request.sequence_id,
      body: result.to_thrift_value(),
    }
  })
  let args : @model.UserDirectoryGetUserArgs = { id: 7L, }
  let request : @protocol.Message = {
    name: "get_user",
    kind: Call,
    sequence_id: 1,
    body: args.to_thrift_value(),
  }
  let reply = transport.call(request)
  match @model.UserDirectoryGetUserResult::from_thrift_value(reply.body) {
    Success(user) => println("get_user(7) -> \{user.name}")
    Missing(missing) => println("missing user \{missing.id}")
  }
}
