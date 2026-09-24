///|
async test "framed RPC over native loopback supports both protocols" {
  for wire in [@rpc.RpcProtocol::Binary, Compact] {
    let names = run_demo(wire)
    assert_eq(names, ["Ada", "Ada"])
  }
}
