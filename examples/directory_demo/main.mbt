///|
fn get_user(
  args : @directory.DirectoryGetUserArgs,
) -> @directory.DirectoryGetUserResult raise @protocol.ProtocolError {
  if args.id < 0L {
    raise InvalidMessage("negative user id")
  }
  Success({ id: args.id, display_name: Some("Ada"), })
}

///|
fn run_directory(wire : @rpc.RpcProtocol, framed : Bool) -> String raise {
  let handler : @directory.DirectoryHandler = { get_user, }
  let client = @directory.DirectoryClient::new(wire, request => {
    let payload = if framed {
      @rpc.decode_frame(@rpc.encode_frame(request))
    } else {
      request
    }
    let response = handler.serve_once(wire, payload)
    if framed {
      @rpc.decode_frame(@rpc.encode_frame(response))
    } else {
      response
    }
  })
  let user = match client.get_user({ id: 7L, }) {
    Success(user) => user
  }
  let transport = if framed { "framed" } else { "memory" }
  let protocol = match wire {
    Binary => "Binary"
    Compact => "Compact"
  }
  "\{protocol}/\{transport}: user \{user.id} = \{user.display_name.unwrap_or("unnamed")}"
}

///|
fn main raise {
  for wire in [@rpc.RpcProtocol::Binary, Compact] {
    println(run_directory(wire, false))
    println(run_directory(wire, true))
  }
}
