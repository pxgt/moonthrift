///|
fn compact_type(ty : WireType) -> Byte {
  match ty {
    Stop => 0
    Bool => 1
    Byte => 3
    I16 => 4
    I32 => 5
    I64 => 6
    Double => 7
    Binary => 8
    List => 9
    Set => 10
    Map => 11
    Struct => 12
  }
}

///|
fn compact_type_for_value(value : Value) -> Byte {
  match value {
    BoolValue(false) => 2
    _ => compact_type(value.wire_type())
  }
}

///|
fn wire_type_from_compact(id : Byte) -> (WireType, Bool?) raise ProtocolError {
  match id {
    0 => (Stop, None)
    1 => (Bool, Some(true))
    2 => (Bool, Some(false))
    3 => (Byte, None)
    4 => (I16, None)
    5 => (I32, None)
    6 => (I64, None)
    7 => (Double, None)
    8 => (Binary, None)
    9 => (List, None)
    10 => (Set, None)
    11 => (Map, None)
    12 => (Struct, None)
    value => raise InvalidType(value)
  }
}

///|
fn write_varuint(buffer : @buffer.Buffer, value : UInt64) -> Unit {
  let mut current = value
  while current >= 0x80UL {
    buffer.write_byte(((current & 0x7fUL) | 0x80UL).to_byte())
    current = current >> 7
  }
  buffer.write_byte(current.to_byte())
}

///|
fn zigzag(value : Int64) -> UInt64 {
  ((value << 1) ^ (value >> 63)).reinterpret_as_uint64()
}

///|
fn unzigzag(value : UInt64) -> Int64 {
  let magnitude = (value >> 1).reinterpret_as_int64()
  if (value & 1UL) == 0UL {
    magnitude
  } else {
    -magnitude - 1L
  }
}

///|
fn write_compact_value(
  buffer : @buffer.Buffer,
  value : Value,
) -> Unit raise ProtocolError {
  match value {
    BoolValue(value) => buffer.write_byte(if value { 1 } else { 2 })
    ByteValue(value) => buffer.write_byte(value.to_byte())
    I16Value(value) => write_varuint(buffer, zigzag(value.to_int64()))
    I32Value(value) => write_varuint(buffer, zigzag(value.to_int64()))
    I64Value(value) => write_varuint(buffer, zigzag(value))
    DoubleValue(value) => buffer.write_double_le(value)
    BinaryValue(value) => {
      write_varuint(
        buffer,
        UInt64::extend_uint(value.length().reinterpret_as_uint()),
      )
      buffer.write_bytes(value)
    }
    StructValue(fields) => {
      let mut previous_id = 0
      for field in fields {
        let delta = field.id - previous_id
        let kind = compact_type_for_value(field.value)
        if delta > 0 && delta <= 15 {
          buffer.write_byte(((delta << 4) | kind.to_int()).to_byte())
        } else {
          buffer.write_byte(kind)
          write_varuint(buffer, zigzag(field.id.to_int64()))
        }
        if !(field.value is BoolValue(_)) {
          write_compact_value(buffer, field.value)
        }
        previous_id = field.id
      }
      buffer.write_byte(0)
    }
    MapValue(key_type~, value_type~, entries~) => {
      write_varuint(
        buffer,
        UInt64::extend_uint(entries.length().reinterpret_as_uint()),
      )
      if entries.length() > 0 {
        let key_id = compact_type(key_type)
        let value_id = compact_type(value_type)
        buffer.write_byte(
          ((key_id.to_int() << 4) | value_id.to_int()).to_byte(),
        )
        for entry in entries {
          let (key, entry_value) = entry
          if key.wire_type() != key_type {
            raise TypeMismatch(expected=key_type, actual=key.wire_type())
          }
          if entry_value.wire_type() != value_type {
            raise TypeMismatch(
              expected=value_type,
              actual=entry_value.wire_type(),
            )
          }
          write_compact_value(buffer, key)
          write_compact_value(buffer, entry_value)
        }
      }
    }
    ListValue(element_type~, values~) | SetValue(element_type~, values~) => {
      let kind = compact_type(element_type)
      if values.length() <= 14 {
        buffer.write_byte(((values.length() << 4) | kind.to_int()).to_byte())
      } else {
        buffer.write_byte((0xf0 | kind.to_int()).to_byte())
        write_varuint(
          buffer,
          UInt64::extend_uint(values.length().reinterpret_as_uint()),
        )
      }
      for item in values {
        if item.wire_type() != element_type {
          raise TypeMismatch(expected=element_type, actual=item.wire_type())
        }
        write_compact_value(buffer, item)
      }
    }
  }
}

///|
priv struct CompactReader {
  input : Bytes
  mut offset : Int
  max_depth : Int
  max_container_size : Int
  max_binary_size : Int
}

///|
fn CompactReader::remaining(self : CompactReader) -> Int {
  self.input.length() - self.offset
}

///|
fn CompactReader::read_byte(self : CompactReader) -> Byte raise ProtocolError {
  if self.offset >= self.input.length() {
    raise UnexpectedEof(offset=self.offset, needed=1)
  }
  let value = self.input[self.offset]
  self.offset += 1
  value
}

///|
fn CompactReader::read_varuint(
  self : CompactReader,
) -> UInt64 raise ProtocolError {
  let mut value = 0UL
  for shift = 0; shift < 70; shift = shift + 7 {
    let byte = self.read_byte()
    value = value | (UInt64::extend_uint((byte & 0x7f).to_uint()) << shift)
    if (byte & 0x80) == 0 {
      return value
    }
  }
  raise InvalidCompact("varint exceeds ten bytes")
}

///|
fn CompactReader::read_size(self : CompactReader) -> Int raise ProtocolError {
  let size = self.read_varuint()
  if size > self.max_container_size.to_int64().reinterpret_as_uint64() {
    raise LimitExceeded(
      kind="container",
      limit=self.max_container_size,
      actual=size.to_int(),
    )
  }
  size.to_int()
}

///|
fn CompactReader::read_double(
  self : CompactReader,
) -> Double raise ProtocolError {
  if self.remaining() < 8 {
    raise UnexpectedEof(offset=self.offset, needed=8)
  }
  let mut raw = 0UL
  for index in 0..<8 {
    raw = raw |
      (
        UInt64::extend_uint(self.input[self.offset + index].to_uint()) <<
        (index * 8)
      )
  }
  self.offset += 8
  raw.reinterpret_as_double()
}

///|
fn CompactReader::read_binary(
  self : CompactReader,
) -> Bytes raise ProtocolError {
  let length64 = self.read_varuint()
  if length64 > self.max_binary_size.to_int64().reinterpret_as_uint64() {
    raise LimitExceeded(
      kind="binary",
      limit=self.max_binary_size,
      actual=length64.to_int(),
    )
  }
  let length = length64.to_int()
  if self.remaining() < length {
    raise UnexpectedEof(offset=self.offset, needed=length)
  }
  let result = self.input[self.offset:self.offset + length].to_owned()
  self.offset += length
  result
}

///|
fn CompactReader::read_value(
  self : CompactReader,
  ty : WireType,
  depth : Int,
  bool_value? : Bool,
) -> Value raise ProtocolError {
  if depth > self.max_depth {
    raise LimitExceeded(kind="depth", limit=self.max_depth, actual=depth)
  }
  match ty {
    Stop => raise TypeMismatch(expected=Struct, actual=Stop)
    Bool =>
      match bool_value {
        Some(value) => BoolValue(value)
        None =>
          match self.read_byte() {
            1 => BoolValue(true)
            2 => BoolValue(false)
            _ => raise InvalidCompact("boolean value must be 1 or 2")
          }
      }
    Byte => {
      let raw = self.read_byte().to_int()
      ByteValue(if raw >= 128 { raw - 256 } else { raw })
    }
    I16 => I16Value(unzigzag(self.read_varuint()).to_int())
    I32 => I32Value(unzigzag(self.read_varuint()).to_int())
    I64 => I64Value(unzigzag(self.read_varuint()))
    Double => DoubleValue(self.read_double())
    Binary => BinaryValue(self.read_binary())
    Struct => {
      let fields : Array[FieldValue] = []
      let mut previous_id = 0
      while true {
        let header = self.read_byte()
        if header == 0 {
          break
        }
        let delta = (header.to_int() >> 4) & 0x0f
        let type_id = header & 0x0f
        let (field_type, bool_marker) = wire_type_from_compact(type_id)
        let id = if delta == 0 {
          unzigzag(self.read_varuint()).to_int()
        } else {
          previous_id + delta
        }
        let value = match bool_marker {
          Some(marker) =>
            self.read_value(field_type, depth + 1, bool_value=marker)
          None => self.read_value(field_type, depth + 1)
        }
        fields.push({ id, value, })
        previous_id = id
      }
      StructValue(fields)
    }
    Map => {
      let size = self.read_size()
      if size == 0 {
        MapValue(key_type=Stop, value_type=Stop, entries=[])
      } else {
        let types = self.read_byte()
        let (key_type, _) = wire_type_from_compact(types >> 4)
        let (value_type, _) = wire_type_from_compact(types & 0x0f)
        let entries : Array[(Value, Value)] = []
        for _ in 0..<size {
          entries.push(
            (
              self.read_value(key_type, depth + 1),
              self.read_value(value_type, depth + 1),
            ),
          )
        }
        MapValue(key_type~, value_type~, entries~)
      }
    }
    List | Set => {
      let header = self.read_byte()
      let inline_size = (header.to_int() >> 4) & 0x0f
      let size = if inline_size == 15 { self.read_size() } else { inline_size }
      if size > self.max_container_size {
        raise LimitExceeded(
          kind="container",
          limit=self.max_container_size,
          actual=size,
        )
      }
      let (element_type, _) = wire_type_from_compact(header & 0x0f)
      let values : Array[Value] = []
      for _ in 0..<size {
        values.push(self.read_value(element_type, depth + 1))
      }
      if ty is List {
        ListValue(element_type~, values~)
      } else {
        SetValue(element_type~, values~)
      }
    }
  }
}

///|
/// Encodes one value using Apache Thrift's compact protocol.
pub fn encode_compact(value : Value) -> Bytes raise ProtocolError {
  let buffer = Buffer()
  write_compact_value(buffer, value)
  buffer.to_bytes()
}

///|
/// Decodes exactly one compact-protocol value.
pub fn decode_compact(
  input : Bytes,
  ty : WireType,
  max_depth? : Int = 64,
  max_container_size? : Int = 1000000,
  max_binary_size? : Int = 16777216,
) -> Value raise ProtocolError {
  let reader : CompactReader = {
    input,
    offset: 0,
    max_depth,
    max_container_size,
    max_binary_size,
  }
  let value = reader.read_value(ty, 0)
  if reader.remaining() != 0 {
    raise TrailingData(offset=reader.offset, remaining=reader.remaining())
  }
  value
}
