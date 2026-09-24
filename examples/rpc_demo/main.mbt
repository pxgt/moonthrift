///|
fn get_user(
  args : @model.UserDirectoryGetUserArgs,
) -> @model.UserDirectoryGetUserResult raise @protocol.ProtocolError {
  if args.id < 0L {
    raise InvalidMessage("negative user id")
  }
  Success({
    id: args.id,
    name: "Ada",
    role: None,
    aliases: None,
    scores: None,
    flags: None,
    revision: 1,
  })
}

///|
fn list_users(
  _ : @model.UserDirectoryListUsersArgs,
) -> @model.UserDirectoryListUsersResult raise @protocol.ProtocolError {
  raise InvalidMessage("list_users is not implemented in this demo")
}

///|
fn main raise {
  let wire : @rpc.RpcProtocol = Compact
  let handler : @model.UserDirectoryHandler = { get_user, list_users, }
  let client = @model.UserDirectoryClient::new(wire, bytes => {
    handler.serve_once(wire, bytes)
  })
  match client.get_user({ id: 7L, }) {
    Success(user) => println("get_user(7) -> \{user.name}")
    Missing(missing) => println("missing user \{missing.id}")
  }
}
