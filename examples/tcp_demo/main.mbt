///|
/// This is deliberately a one-request-per-connection adapter. The portable
/// RPC package owns message and frame validation; only this package owns I/O.
async fn read_frame(conn : @socket.Tcp) -> Bytes {
  let decoder = @rpc.FrameDecoder::new(max_frame_size=4096)
  for ;; {
    let chunk = match conn.read_some(max_len=7) {
      Some(bytes) => bytes
      None => fail("connection closed before a complete frame")
    }
    let frames = decoder.push(chunk)
    if frames.length() == 1 {
      return frames[0]
    }
    if frames.length() > 1 {
      fail("this tutorial expects one frame per connection")
    }
  }
}

///|
async fn write_frame(conn : @socket.Tcp, payload : Bytes) -> Unit {
  let frame = @rpc.encode_frame(payload, max_frame_size=4096)
  // Split the write intentionally: TCP read boundaries need not match writes.
  conn.write(frame[:2])
  conn.write(frame[2:])
}

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
  raise InvalidMessage("list_users is not implemented in this tutorial")
}

///|
async fn serve_client(
  conn : @socket.Tcp,
  wire : @rpc.RpcProtocol,
  handler : @model.UserDirectoryHandler,
) -> Unit {
  defer conn.close()
  let request = read_frame(conn)
  let response = handler.serve_once(wire, request)
  write_frame(conn, response)
}

///|
async fn call_get_user(
  addr : @socket.Addr,
  wire : @rpc.RpcProtocol,
  id : Int64,
  sequence_id : Int,
) -> String {
  let conn = @socket.Tcp::connect(addr)
  defer conn.close()
  let args : @model.UserDirectoryGetUserArgs = { id, }
  let request : @protocol.Message = {
    name: "get_user",
    kind: Call,
    sequence_id,
    body: args.to_thrift_value(),
  }
  write_frame(conn, wire.encode(request))
  let reply = wire.decode(read_frame(conn))
  if reply.name != request.name ||
    reply.sequence_id != sequence_id ||
    !(reply.kind is Reply) {
    fail("unexpected RPC reply")
  }
  match @model.UserDirectoryGetUserResult::from_thrift_value(reply.body) {
    Success(user) => user.name
    Missing(_) => fail("unexpected missing user")
  }
}

///|
async fn run_demo(wire : @rpc.RpcProtocol) -> Array[String] {
  let results : Array[String] = []
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  let addr = server.addr
  let handler : @model.UserDirectoryHandler = { get_user, list_users, }
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      for _ in 0..<2 {
        let (conn, _) = server.accept()
        serve_client(conn, wire, handler)
      }
    })
    group.spawn_bg(() => {
      results.push(call_get_user(addr, wire, 7L, 1))
      results.push(call_get_user(addr, wire, 8L, 2))
    })
  })
  results
}

///|
async fn main {
  for wire in [@rpc.RpcProtocol::Binary, Compact] {
    let names = run_demo(wire)
    let protocol_name = match wire {
      Binary => "Binary"
      Compact => "Compact"
    }
    println("TCP \{protocol_name}: \{names.join(", ")}")
  }
}
