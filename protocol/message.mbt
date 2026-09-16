///|
fn decode_utf8(bytes : Bytes) -> String raise ProtocolError {
  @utf8.decode(bytes) catch {
    _ => raise InvalidMessage("message name is not valid UTF-8")
  }
}

///|
/// Encodes a strict-version binary protocol message envelope and struct body.
pub fn encode_binary_message(message : Message) -> Bytes raise ProtocolError {
  if !(message.body is StructValue(_)) {
    raise TypeMismatch(expected=Struct, actual=message.body.wire_type())
  }
  let buffer = Buffer()
  let version_and_type : UInt = 0x80010000U |
    message.kind.id().reinterpret_as_uint()
  buffer.write_uint_be(version_and_type)
  let name = @utf8.encode(message.name)
  buffer.write_int_be(name.length())
  buffer.write_bytes(name)
  buffer.write_int_be(message.sequence_id)
  write_compact_or_binary_body(buffer, message.body)
  buffer.to_bytes()
}

///|
fn write_compact_or_binary_body(
  buffer : @buffer.Buffer,
  body : Value,
) -> Unit raise ProtocolError {
  write_value(buffer, body)
}

///|
/// Decodes a strict-version binary message and rejects trailing bytes.
pub fn decode_binary_message(
  input : Bytes,
  max_depth? : Int = 64,
  max_container_size? : Int = 1000000,
  max_binary_size? : Int = 16777216,
) -> Message raise ProtocolError {
  let reader : BinaryReader = {
    input,
    offset: 0,
    max_depth,
    max_container_size,
    max_binary_size,
  }
  let header = reader.read_i32().reinterpret_as_uint()
  if (header & 0xffff0000U) != 0x80010000U {
    raise InvalidMessage("binary message is missing strict version 1 header")
  }
  let kind = MessageType::from_id((header & 0xffU).reinterpret_as_int())
  let name = decode_utf8(reader.read_binary())
  let sequence_id = reader.read_i32()
  let body = reader.read_value(Struct, 0)
  if reader.remaining() != 0 {
    raise TrailingData(offset=reader.offset, remaining=reader.remaining())
  }
  { name, kind, sequence_id, body, }
}

///|
/// Encodes a compact protocol message envelope and struct body.
pub fn encode_compact_message(message : Message) -> Bytes raise ProtocolError {
  if !(message.body is StructValue(_)) {
    raise TypeMismatch(expected=Struct, actual=message.body.wire_type())
  }
  let buffer = Buffer()
  buffer.write_byte(0x82)
  buffer.write_byte(((message.kind.id() << 5) | 1).to_byte())
  write_varuint(
    buffer,
    UInt64::extend_uint(message.sequence_id.reinterpret_as_uint()),
  )
  let name = @utf8.encode(message.name)
  write_varuint(
    buffer,
    UInt64::extend_uint(name.length().reinterpret_as_uint()),
  )
  buffer.write_bytes(name)
  write_compact_value(buffer, message.body)
  buffer.to_bytes()
}

///|
/// Decodes a compact protocol message and validates protocol/version bytes.
pub fn decode_compact_message(
  input : Bytes,
  max_depth? : Int = 64,
  max_container_size? : Int = 1000000,
  max_binary_size? : Int = 16777216,
) -> Message raise ProtocolError {
  let reader : CompactReader = {
    input,
    offset: 0,
    max_depth,
    max_container_size,
    max_binary_size,
  }
  if reader.read_byte() != 0x82 {
    raise InvalidMessage("compact message is missing protocol id 0x82")
  }
  let version_and_type = reader.read_byte().to_int()
  if (version_and_type & 0x1f) != 1 {
    raise InvalidMessage("unsupported compact protocol version")
  }
  let kind = MessageType::from_id((version_and_type >> 5) & 0x07)
  let sequence_id = reader.read_varuint().to_int()
  let name = decode_utf8(reader.read_binary())
  let body = reader.read_value(Struct, 0)
  if reader.remaining() != 0 {
    raise TrailingData(offset=reader.offset, remaining=reader.remaining())
  }
  { name, kind, sequence_id, body, }
}
