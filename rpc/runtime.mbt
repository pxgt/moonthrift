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
/// response. This increment accepts CALL only; oneway and application-level
/// exception conversion are separate Phase 5 work.
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
