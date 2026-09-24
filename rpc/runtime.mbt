///|
/// Selects the existing Thrift message codec without coupling RPC dispatch
/// to a filesystem, socket, scheduler, or target-specific I/O library.
pub(all) enum RpcProtocol {
  Binary
  Compact
} derive(Debug, Eq)

///|
pub fn RpcProtocol::encode(
  self : RpcProtocol,
  message : @protocol.Message,
) -> Bytes raise @protocol.ProtocolError {
  match self {
    Binary => @protocol.encode_binary_message(message)
    Compact => @protocol.encode_compact_message(message)
  }
}

///|
pub fn RpcProtocol::decode(
  self : RpcProtocol,
  bytes : Bytes,
) -> @protocol.Message raise @protocol.ProtocolError {
  match self {
    Binary => @protocol.decode_binary_message(bytes)
    Compact => @protocol.decode_compact_message(bytes)
  }
}

///|
fn require_call(
  request : @protocol.Message,
) -> Unit raise @protocol.ProtocolError {
  if !(request.kind is Call) {
    raise InvalidMessage("RPC request must have CALL message type")
  }
}

///|
fn require_reply(
  request : @protocol.Message,
  reply : @protocol.Message,
) -> Unit raise @protocol.ProtocolError {
  if !(reply.kind is Reply || reply.kind is Exception) {
    raise InvalidMessage(
      "RPC response must have REPLY or EXCEPTION message type",
    )
  }
  if reply.name != request.name {
    raise InvalidMessage("RPC response method does not match request")
  }
  if reply.sequence_id != request.sequence_id {
    raise InvalidMessage("RPC response sequence ID does not match request")
  }
}

///|
/// Decodes one request, invokes its application handler, and encodes one
/// response. This compatibility API accepts CALL only; use
/// `process_once_optional` for services with ONEWAY methods.
pub fn process_once(
  wire : RpcProtocol,
  request_bytes : Bytes,
  handler : (@protocol.Message) -> @protocol.Message raise @protocol.ProtocolError,
) -> Bytes raise @protocol.ProtocolError {
  let request = wire.decode(request_bytes)
  require_call(request)
  let reply = handler(request)
  require_reply(request, reply)
  wire.encode(reply)
}

///|
/// Processes a CALL or ONEWAY request. ONEWAY must produce no response,
/// including when the application handler reports an error.
pub fn process_once_optional(
  wire : RpcProtocol,
  request_bytes : Bytes,
  handler : (@protocol.Message) -> @protocol.Message? raise @protocol.ProtocolError,
) -> Bytes? raise @protocol.ProtocolError {
  let request = wire.decode(request_bytes)
  if !(request.kind is Call || request.kind is Oneway) {
    raise InvalidMessage("RPC request must have CALL or ONEWAY message type")
  }
  let reply = handler(request)
  match (request.kind, reply) {
    (Call, Some(message)) => {
      require_reply(request, message)
      Some(wire.encode(message))
    }
    (Oneway, None) => None
    (Call, None) => raise InvalidMessage("CALL handler did not return a reply")
    (Oneway, Some(_)) =>
      raise InvalidMessage("ONEWAY handler must not return a reply")
    _ => raise InvalidMessage("invalid RPC request type")
  }
}

///|
/// A transport boundary expressed as bytes in, bytes out. The exchange
/// callback may later be backed by framed TCP or another I/O adapter.
pub fn call_once(
  wire : RpcProtocol,
  request : @protocol.Message,
  exchange : (Bytes) -> Bytes raise @protocol.ProtocolError,
) -> @protocol.Message raise @protocol.ProtocolError {
  require_call(request)
  let reply = wire.decode(exchange(wire.encode(request)))
  require_reply(request, reply)
  reply
}

///|
/// Calls through an optional-response byte exchange. A CALL must have a
/// response; the same exchange can also carry ONEWAY messages.
pub fn call_once_optional(
  wire : RpcProtocol,
  request : @protocol.Message,
  exchange : (Bytes) -> Bytes? raise @protocol.ProtocolError,
) -> @protocol.Message raise @protocol.ProtocolError {
  require_call(request)
  let reply_bytes = match exchange(wire.encode(request)) {
    Some(bytes) => bytes
    None => raise InvalidMessage("CALL transport did not return a reply")
  }
  let reply = wire.decode(reply_bytes)
  require_reply(request, reply)
  reply
}

///|
/// Sends a ONEWAY request without reading or expecting a response.
pub fn send_oneway(
  wire : RpcProtocol,
  request : @protocol.Message,
  exchange : (Bytes) -> Bytes? raise @protocol.ProtocolError,
) -> Unit raise @protocol.ProtocolError {
  if !(request.kind is Oneway) {
    raise InvalidMessage("RPC request must have ONEWAY message type")
  }
  match exchange(wire.encode(request)) {
    None => ()
    Some(_) => raise InvalidMessage("ONEWAY transport returned a reply")
  }
}

///|
/// Synchronous in-process byte transport for tests, examples, and embedders.
/// Each call crosses the same encode/decode boundary as a network adapter.
pub struct MemoryTransport {
  wire : RpcProtocol
  handler : (@protocol.Message) -> @protocol.Message raise @protocol.ProtocolError
}

///|
pub fn MemoryTransport::new(
  wire : RpcProtocol,
  handler : (@protocol.Message) -> @protocol.Message raise @protocol.ProtocolError,
) -> MemoryTransport {
  { wire, handler, }
}

///|
pub fn MemoryTransport::call(
  self : MemoryTransport,
  request : @protocol.Message,
) -> @protocol.Message raise @protocol.ProtocolError {
  call_once(self.wire, request, bytes => {
    process_once(self.wire, bytes, self.handler)
  })
}
