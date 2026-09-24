///|
/// Runtime facades are emitted only when every method has request/reply
/// semantics. Inherited and oneway methods need additional dispatch rules.
fn render_service_rpc_runtime(
  output : StringBuilder,
  service_name : String,
  extends : String?,
  functions : ArrayView[@moonthrift.FunctionDef],
) -> Unit {
  if extends is Some(_) ||
    functions.is_empty() ||
    functions.any(function => function.oneway) {
    return
  }
  let service = type_name(service_name)
  let client = "\{service}Client"
  let handler = "\{service}Handler"
  output.write_string(
    "///|\n/// Typed request/reply client for Thrift service \{service_name}.\npub struct \{client} {\n  wire : @rpc.RpcProtocol\n  exchange : (Bytes) -> Bytes raise @protocol.ProtocolError\n  mut next_sequence_id : Int\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{client}::new(wire : @rpc.RpcProtocol, exchange : (Bytes) -> Bytes raise @protocol.ProtocolError) -> \{client} {\n  { wire, exchange, next_sequence_id: 1, }\n}\n\n",
  )
  for function in functions {
    let method_name = value_name(function.name)
    let prefix = "\{service}\{type_name(function.name)}"
    output.write_string(
      "///|\npub fn \{client}::\{method_name}(self : \{client}, args : \{prefix}Args) -> \{prefix}Result raise @protocol.ProtocolError {\n  let sequence_id = self.next_sequence_id\n  self.next_sequence_id += 1\n  let request : @protocol.Message = {\n    name: \{escape_string(function.name)},\n    kind: Call,\n    sequence_id,\n    body: args.to_thrift_value(),\n  }\n  let reply = @rpc.call_once(self.wire, request, self.exchange)\n  if reply.kind is Exception {\n    raise InvalidMessage(\{escape_string("application exception returned by \{service_name}.\{function.name}; decoding is not implemented yet")})\n  }\n  \{prefix}Result::from_thrift_value(reply.body)\n}\n\n",
    )
  }
  output.write_string(
    "///|\n/// Typed callbacks for the methods of \{service_name}.\npub(all) struct \{handler} {\n",
  )
  for function in functions {
    let method_name = value_name(function.name)
    let prefix = "\{service}\{type_name(function.name)}"
    output.write_string(
      "  \{method_name} : (\{prefix}Args) -> \{prefix}Result raise @protocol.ProtocolError\n",
    )
  }
  output.write_string("}\n\n")
  output.write_string(
    "///|\npub fn \{handler}::process(self : \{handler}, request : @protocol.Message) -> @protocol.Message raise @protocol.ProtocolError {\n  if !(request.kind is Call) {\n    raise InvalidMessage(\"RPC request must have CALL message type\")\n  }\n  match request.name {\n",
  )
  for function in functions {
    let method_name = value_name(function.name)
    let prefix = "\{service}\{type_name(function.name)}"
    output.write_string(
      "    \{escape_string(function.name)} => {\n      let args = \{prefix}Args::from_thrift_value(request.body)\n      let result = (self.\{method_name})(args)\n      {\n        name: request.name,\n        kind: Reply,\n        sequence_id: request.sequence_id,\n        body: result.to_thrift_value(),\n      }\n    }\n",
    )
  }
  output.write_string(
    "    _ => raise InvalidMessage(\"unknown RPC method \\{request.name}\")\n  }\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{handler}::serve_once(self : \{handler}, wire : @rpc.RpcProtocol, request_bytes : Bytes) -> Bytes raise @protocol.ProtocolError {\n  @rpc.process_once(wire, request_bytes, request => self.process(request))\n}\n\n",
  )
}
