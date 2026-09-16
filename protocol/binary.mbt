///|
priv struct BinaryReader {
  input : Bytes
  mut offset : Int
  max_depth : Int
  max_container_size : Int
  max_binary_size : Int
}

///|
fn BinaryReader::remaining(self : BinaryReader) -> Int {
  self.input.length() - self.offset
}

///|
fn BinaryReader::require(
  self : BinaryReader,
  count : Int,
) -> Unit raise ProtocolError {
  if count < 0 || self.remaining() < count {
    raise UnexpectedEof(offset=self.offset, needed=count)
  }
}

///|
fn BinaryReader::read_byte(self : BinaryReader) -> Byte raise ProtocolError {
  self.require(1)
  let value = self.input[self.offset]
  self.offset += 1
  value
}

///|
fn BinaryReader::read_i16(self : BinaryReader) -> Int raise ProtocolError {
  self.require(2)
  let raw = (self.input[self.offset].to_int() << 8) |
    self.input[self.offset + 1].to_int()
  self.offset += 2
  if raw >= 0x8000 {
    raw - 0x10000
  } else {
    raw
  }
}

///|
fn BinaryReader::read_i32(self : BinaryReader) -> Int raise ProtocolError {
  self.require(4)
  let raw : UInt = (self.input[self.offset].to_uint() << 24) |
    (self.input[self.offset + 1].to_uint() << 16) |
    (self.input[self.offset + 2].to_uint() << 8) |
    self.input[self.offset + 3].to_uint()
  self.offset += 4
  raw.reinterpret_as_int()
}

///|
fn BinaryReader::read_i64(self : BinaryReader) -> Int64 raise ProtocolError {
  self.require(8)
  let mut raw = 0UL
  for index in 0..<8 {
    raw = (raw << 8) |
      UInt64::extend_uint(self.input[self.offset + index].to_uint())
  }
  self.offset += 8
  raw.reinterpret_as_int64()
}

///|
fn BinaryReader::read_binary(self : BinaryReader) -> Bytes raise ProtocolError {
  let length = self.read_i32()
  if length < 0 {
    raise NegativeSize(length)
  }
  if length > self.max_binary_size {
    raise LimitExceeded(
      kind="binary",
      limit=self.max_binary_size,
      actual=length,
    )
  }
  self.require(length)
  let value = self.input[self.offset:self.offset + length].to_owned()
  self.offset += length
  value
}

///|
fn BinaryReader::check_container(
  self : BinaryReader,
  size : Int,
) -> Unit raise ProtocolError {
  if size < 0 {
    raise NegativeSize(size)
  }
  if size > self.max_container_size {
    raise LimitExceeded(
      kind="container",
      limit=self.max_container_size,
      actual=size,
    )
  }
}

///|
fn BinaryReader::read_value(
  self : BinaryReader,
  ty : WireType,
  depth : Int,
) -> Value raise ProtocolError {
  if depth > self.max_depth {
    raise LimitExceeded(kind="depth", limit=self.max_depth, actual=depth)
  }
  match ty {
    Stop => raise TypeMismatch(expected=Struct, actual=Stop)
    Bool => BoolValue(self.read_byte() != 0)
    Byte => {
      let raw = self.read_byte().to_int()
      ByteValue(if raw >= 128 { raw - 256 } else { raw })
    }
    I16 => I16Value(self.read_i16())
    I32 => I32Value(self.read_i32())
    I64 => I64Value(self.read_i64())
    Double => DoubleValue(self.read_i64().reinterpret_as_double())
    Binary => BinaryValue(self.read_binary())
    Struct => {
      let fields : Array[FieldValue] = []
      while true {
        let field_type = WireType::from_binary_id(self.read_byte())
        if field_type is Stop {
          break
        }
        let id = self.read_i16()
        let value = self.read_value(field_type, depth + 1)
        fields.push({ id, value, })
      }
      StructValue(fields)
    }
    Map => {
      let key_type = WireType::from_binary_id(self.read_byte())
      let value_type = WireType::from_binary_id(self.read_byte())
      let size = self.read_i32()
      self.check_container(size)
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
    List | Set => {
      let element_type = WireType::from_binary_id(self.read_byte())
      let size = self.read_i32()
      self.check_container(size)
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
fn write_type_checked(
  buffer : @buffer.Buffer,
  expected : WireType,
  value : Value,
) -> Unit raise ProtocolError {
  let actual = value.wire_type()
  if expected != actual {
    raise TypeMismatch(expected~, actual~)
  }
  write_value(buffer, value)
}

///|
fn write_value(
  buffer : @buffer.Buffer,
  value : Value,
) -> Unit raise ProtocolError {
  match value {
    BoolValue(value) => buffer.write_byte(if value { 1 } else { 0 })
    ByteValue(value) => buffer.write_byte(value.to_byte())
    I16Value(value) => buffer.write_int16_be(Int16::from_int(value))
    I32Value(value) => buffer.write_int_be(value)
    I64Value(value) => buffer.write_int64_be(value)
    DoubleValue(value) => buffer.write_double_be(value)
    BinaryValue(value) => {
      buffer.write_int_be(value.length())
      buffer.write_bytes(value)
    }
    StructValue(fields) => {
      for field in fields {
        buffer.write_byte(field.value.wire_type().binary_id())
        buffer.write_int16_be(Int16::from_int(field.id))
        write_value(buffer, field.value)
      }
      buffer.write_byte(Stop.binary_id())
    }
    MapValue(key_type~, value_type~, entries~) => {
      buffer.write_byte(key_type.binary_id())
      buffer.write_byte(value_type.binary_id())
      buffer.write_int_be(entries.length())
      for entry in entries {
        let (key, entry_value) = entry
        write_type_checked(buffer, key_type, key)
        write_type_checked(buffer, value_type, entry_value)
      }
    }
    SetValue(element_type~, values~) | ListValue(element_type~, values~) => {
      buffer.write_byte(element_type.binary_id())
      buffer.write_int_be(values.length())
      for item in values {
        write_type_checked(buffer, element_type, item)
      }
    }
  }
}

///|
/// Encodes one value using Apache Thrift's standard binary protocol.
pub fn encode_binary(value : Value) -> Bytes raise ProtocolError {
  let buffer = Buffer()
  write_value(buffer, value)
  buffer.to_bytes()
}

///|
/// Decodes exactly one value using the expected top-level wire type.
pub fn decode_binary(
  input : Bytes,
  ty : WireType,
  max_depth? : Int = 64,
  max_container_size? : Int = 1000000,
  max_binary_size? : Int = 16777216,
) -> Value raise ProtocolError {
  let reader = {
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
