///|
/// Inherited services need a separate method-flattening pass. ONEWAY methods
/// use an optional-response exchange so the handler never emits a reply.
fn render_service_rpc_runtime(
  output : StringBuilder,
  service_name : String,
  extends : String?,
  functions : ArrayView[@moonthrift.FunctionDef],
) -> Unit {
  if extends is Some(_) || functions.is_empty() {
    return
  }
  let has_oneway = functions.any(function => function.oneway)
  let service = type_name(service_name)
  let client = "\{service}Client"
  let handler = "\{service}Handler"
  let exchange_type = if has_oneway {
    "(Bytes) -> Bytes? raise @protocol.ProtocolError"
  } else {
    "(Bytes) -> Bytes raise @protocol.ProtocolError"
  }
  output.write_string(
    "///|\n/// Typed client for Thrift service \{service_name}.\npub struct \{client} {\n  wire : @rpc.RpcProtocol\n  exchange : \{exchange_type}\n  mut next_sequence_id : Int\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{client}::new(wire : @rpc.RpcProtocol, exchange : \{exchange_type}) -> \{client} {\n  { wire, exchange, next_sequence_id: 1, }\n}\n\n",
  )
  for function in functions {
    let method_name = value_name(function.name)
    let prefix = "\{service}\{type_name(function.name)}"
    if function.oneway {
      output.write_string(
        "///|\npub fn \{client}::\{method_name}(self : \{client}, args : \{prefix}Args) -> Unit raise @protocol.ProtocolError {\n  let sequence_id = self.next_sequence_id\n  self.next_sequence_id += 1\n  let request : @protocol.Message = {\n    name: \{escape_string(function.name)},\n    kind: Oneway,\n    sequence_id,\n    body: args.to_thrift_value(),\n  }\n  @rpc.send_oneway(self.wire, request, self.exchange)\n}\n\n",
      )
    } else {
      let call_fn = if has_oneway { "call_once_optional" } else { "call_once" }
      output.write_string(
        "///|\npub fn \{client}::\{method_name}(self : \{client}, args : \{prefix}Args) -> \{prefix}Result raise @protocol.ProtocolError {\n  let sequence_id = self.next_sequence_id\n  self.next_sequence_id += 1\n  let request : @protocol.Message = {\n    name: \{escape_string(function.name)},\n    kind: Call,\n    sequence_id,\n    body: args.to_thrift_value(),\n  }\n  let reply = @rpc.\{call_fn}(self.wire, request, self.exchange)\n  \{prefix}Result::from_thrift_value(@rpc.reply_result_body(reply))\n}\n\n",
      )
    }
  }
  output.write_string(
    "///|\n/// Typed callbacks for the methods of \{service_name}.\npub(all) struct \{handler} {\n",
  )
  for function in functions {
    let method_name = value_name(function.name)
    let prefix = "\{service}\{type_name(function.name)}"
    if function.oneway {
      output.write_string(
        "  \{method_name} : (\{prefix}Args) -> Unit raise @protocol.ProtocolError\n",
      )
    } else {
      output.write_string(
        "  \{method_name} : (\{prefix}Args) -> \{prefix}Result raise @protocol.ProtocolError\n",
      )
    }
  }
  output.write_string("}\n\n")
  let response_type = if has_oneway {
    "@protocol.Message?"
  } else {
    "@protocol.Message"
  }
  let allowed_kind = if has_oneway { "CALL or ONEWAY" } else { "CALL" }
  let request_guard = if has_oneway {
    "request.kind is Call || request.kind is Oneway"
  } else {
    "request.kind is Call"
  }
  output.write_string(
    "///|\npub fn \{handler}::process(self : \{handler}, request : @protocol.Message) -> \{response_type} raise @protocol.ProtocolError {\n  if !(\{request_guard}) {\n    raise InvalidMessage(\"RPC request must have \{allowed_kind} message type\")\n  }\n  match request.name {\n",
  )
  for function in functions {
    let method_name = value_name(function.name)
    let prefix = "\{service}\{type_name(function.name)}"
    if function.oneway {
      output.write_string(
        "    \{escape_string(function.name)} => {\n      if !(request.kind is Oneway) {\n        Some(@rpc.application_exception_reply(request, 2, \"expected ONEWAY request\"))\n      } else {\n        let args = \{prefix}Args::from_thrift_value(request.body)\n        (self.\{method_name})(args)\n        None\n      }\n    }\n",
      )
    } else {
      let result_prefix = if has_oneway { "Some(" } else { "" }
      let result_suffix = if has_oneway { ")" } else { "" }
      let kind_guard = if has_oneway {
        "      if !(request.kind is Call) {\n        return None\n      }\n"
      } else {
        ""
      }
      output.write_string(
        "    \{escape_string(function.name)} => {\n\{kind_guard}      let args = \{prefix}Args::from_thrift_value(request.body) catch {\n        _ => return \{result_prefix}@rpc.application_exception_reply(request, 7, \"invalid RPC arguments\")\{result_suffix}\n      }\n      let result = (self.\{method_name})(args) catch {\n        _ => return \{result_prefix}@rpc.application_exception_reply(request, 6, \"RPC handler failed\")\{result_suffix}\n      }\n      \{result_prefix}{\n        name: request.name,\n        kind: Reply,\n        sequence_id: request.sequence_id,\n        body: result.to_thrift_value(),\n      }\{result_suffix}\n    }\n",
      )
    }
  }
  if has_oneway {
    output.write_string(
      "    _ => if request.kind is Oneway { None } else { Some(@rpc.application_exception_reply(request, 1, \"unknown RPC method \\{request.name}\")) }\n  }\n}\n\n",
    )
    output.write_string(
      "///|\npub fn \{handler}::serve_once(self : \{handler}, wire : @rpc.RpcProtocol, request_bytes : Bytes) -> Bytes? raise @protocol.ProtocolError {\n  @rpc.process_once_optional(wire, request_bytes, request => self.process(request))\n}\n\n",
    )
  } else {
    output.write_string(
      "    _ => @rpc.application_exception_reply(request, 1, \"unknown RPC method \\{request.name}\")\n  }\n}\n\n",
    )
    output.write_string(
      "///|\npub fn \{handler}::serve_once(self : \{handler}, wire : @rpc.RpcProtocol, request_bytes : Bytes) -> Bytes raise @protocol.ProtocolError {\n  @rpc.process_once(wire, request_bytes, request => self.process(request))\n}\n\n",
    )
  }
}
