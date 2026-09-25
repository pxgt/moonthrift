///|
test "multi-file directory service runs on both wire protocols" {
  for wire in [@rpc.RpcProtocol::Binary, Compact] {
    let protocol = match wire {
      Binary => "Binary"
      Compact => "Compact"
    }
    assert_eq(run_directory(wire, false), "\{protocol}/memory: user 7 = Ada")
    assert_eq(run_directory(wire, true), "\{protocol}/framed: user 7 = Ada")
  }
}

///|
test "multi-file directory service converts handler failure to an RPC exception" {
  let handler : @directory.DirectoryHandler = { get_user, }
  for wire in [@rpc.RpcProtocol::Binary, Compact] {
    let client = @directory.DirectoryClient::new(wire, request => {
      handler.serve_once(wire, request)
    })
    try client.get_user({ id: -1L, }) catch {
      ApplicationException(message~, type_code~) => {
        assert_eq(type_code, 6)
        assert_eq(message, "RPC handler failed")
      }
      _ => fail("unexpected RPC error")
    } noraise {
      _ => fail("expected a handler failure")
    }
  }
}
