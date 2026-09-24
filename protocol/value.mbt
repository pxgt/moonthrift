///|
/// Thrift wire type IDs shared by the binary and compact protocols.
pub(all) enum WireType {
  Stop
  Bool
  Byte
  Double
  I16
  I32
  I64
  Binary
  Struct
  Map
  Set
  List
} derive(Debug, Eq)

///|
pub fn WireType::binary_id(self : WireType) -> Byte {
  match self {
    Stop => 0
    Bool => 2
    Byte => 3
    Double => 4
    I16 => 6
    I32 => 8
    I64 => 10
    Binary => 11
    Struct => 12
    Map => 13
    Set => 14
    List => 15
  }
}

///|
pub fn WireType::from_binary_id(id : Byte) -> WireType raise ProtocolError {
  match id {
    0 => Stop
    2 => Bool
    3 => Byte
    4 => Double
    6 => I16
    8 => I32
    10 => I64
    11 => Binary
    12 => Struct
    13 => Map
    14 => Set
    15 => List
    value => raise InvalidType(value)
  }
}

///|
/// One field in a dynamically represented Thrift struct.
pub(all) struct FieldValue {
  id : Int
  value : Value
} derive(Debug, Eq)

///|
/// A schema-independent value preserving all wire type information.
pub(all) enum Value {
  BoolValue(Bool)
  ByteValue(Int)
  I16Value(Int)
  I32Value(Int)
  I64Value(Int64)
  DoubleValue(Double)
  BinaryValue(Bytes)
  StructValue(Array[FieldValue])
  MapValue(
    key_type~ : WireType,
    value_type~ : WireType,
    entries~ : Array[(Value, Value)]
  )
  SetValue(element_type~ : WireType, values~ : Array[Value])
  ListValue(element_type~ : WireType, values~ : Array[Value])
} derive(Debug, Eq)

///|
pub(all) enum MessageType {
  Call
  Reply
  Exception
  Oneway
} derive(Debug, Eq)

///|
pub fn MessageType::id(self : MessageType) -> Int {
  match self {
    Call => 1
    Reply => 2
    Exception => 3
    Oneway => 4
  }
}

///|
pub fn MessageType::from_id(id : Int) -> MessageType raise ProtocolError {
  match id {
    1 => Call
    2 => Reply
    3 => Exception
    4 => Oneway
    _ => raise InvalidMessage("unknown message type \{id}")
  }
}

///|
/// A complete Thrift RPC message independent of any transport.
pub(all) struct Message {
  name : String
  kind : MessageType
  sequence_id : Int
  body : Value
} derive(Debug, Eq)

///|
pub fn Value::wire_type(self : Value) -> WireType {
  match self {
    BoolValue(_) => Bool
    ByteValue(_) => Byte
    I16Value(_) => I16
    I32Value(_) => I32
    I64Value(_) => I64
    DoubleValue(_) => Double
    BinaryValue(_) => Binary
    StructValue(_) => Struct
    MapValue(..) => Map
    SetValue(..) => Set
    ListValue(..) => List
  }
}

///|
/// Finds a field by its numeric Thrift identifier.
///
/// Unknown fields remain available to callers but generated decoders can
/// deliberately ignore them, which preserves Thrift's forward-compatibility
/// behavior.
pub fn find_field(fields : ArrayView[FieldValue], id : Int) -> Value? {
  for field in fields {
    if field.id == id {
      return Some(field.value)
    }
  }
  None
}

///|
/// Converts UTF-8 text into Thrift's binary wire representation.
pub fn string_value(value : String) -> Value {
  BinaryValue(@utf8.encode(value))
}

///|
pub fn Value::require_bool(self : Value) -> Bool raise ProtocolError {
  match self {
    BoolValue(value) => value
    value => raise TypeMismatch(expected=Bool, actual=value.wire_type())
  }
}

///|
pub fn Value::require_byte(self : Value) -> Byte raise ProtocolError {
  match self {
    ByteValue(value) => value.to_byte()
    value => raise TypeMismatch(expected=Byte, actual=value.wire_type())
  }
}

///|
pub fn Value::require_i16(self : Value) -> Int raise ProtocolError {
  match self {
    I16Value(value) => value
    value => raise TypeMismatch(expected=I16, actual=value.wire_type())
  }
}

///|
pub fn Value::require_i32(self : Value) -> Int raise ProtocolError {
  match self {
    I32Value(value) => value
    value => raise TypeMismatch(expected=I32, actual=value.wire_type())
  }
}

///|
pub fn Value::require_i64(self : Value) -> Int64 raise ProtocolError {
  match self {
    I64Value(value) => value
    value => raise TypeMismatch(expected=I64, actual=value.wire_type())
  }
}

///|
pub fn Value::require_double(self : Value) -> Double raise ProtocolError {
  match self {
    DoubleValue(value) => value
    value => raise TypeMismatch(expected=Double, actual=value.wire_type())
  }
}

///|
pub fn Value::require_binary(self : Value) -> Bytes raise ProtocolError {
  match self {
    BinaryValue(value) => value
    value => raise TypeMismatch(expected=Binary, actual=value.wire_type())
  }
}

///|
pub fn Value::require_string(self : Value) -> String raise ProtocolError {
  let bytes = self.require_binary()
  @utf8.decode(bytes) catch {
    _ => raise InvalidValue("binary field is not valid UTF-8")
  }
}

///|
pub fn Value::require_struct(
  self : Value,
) -> Array[FieldValue] raise ProtocolError {
  match self {
    StructValue(fields) => fields
    value => raise TypeMismatch(expected=Struct, actual=value.wire_type())
  }
}

///|
pub fn Value::require_list(
  self : Value,
  expected_element_type : WireType,
) -> Array[Value] raise ProtocolError {
  match self {
    ListValue(element_type~, values~) => {
      if element_type != expected_element_type && values.length() > 0 {
        raise TypeMismatch(expected=expected_element_type, actual=element_type)
      }
      values
    }
    value => raise TypeMismatch(expected=List, actual=value.wire_type())
  }
}

///|
pub fn Value::require_set(
  self : Value,
  expected_element_type : WireType,
) -> Array[Value] raise ProtocolError {
  match self {
    SetValue(element_type~, values~) => {
      if element_type != expected_element_type && values.length() > 0 {
        raise TypeMismatch(expected=expected_element_type, actual=element_type)
      }
      values
    }
    value => raise TypeMismatch(expected=Set, actual=value.wire_type())
  }
}

///|
pub fn Value::require_map(
  self : Value,
  expected_key_type : WireType,
  expected_value_type : WireType,
) -> Array[(Value, Value)] raise ProtocolError {
  match self {
    MapValue(key_type~, value_type~, entries~) => {
      if entries.length() > 0 && key_type != expected_key_type {
        raise TypeMismatch(expected=expected_key_type, actual=key_type)
      }
      if entries.length() > 0 && value_type != expected_value_type {
        raise TypeMismatch(expected=expected_value_type, actual=value_type)
      }
      entries
    }
    value => raise TypeMismatch(expected=Map, actual=value.wire_type())
  }
}

///|
/// Errors are bounded and deterministic so malformed untrusted payloads do not
/// become panics or unbounded allocations.
pub(all) suberror ProtocolError {
  UnexpectedEof(offset~ : Int, needed~ : Int)
  InvalidType(Byte)
  TypeMismatch(expected~ : WireType, actual~ : WireType)
  NegativeSize(Int)
  LimitExceeded(kind~ : String, limit~ : Int, actual~ : Int)
  TrailingData(offset~ : Int, remaining~ : Int)
  InvalidCompact(String)
  InvalidMessage(String)
  ApplicationException(message~ : String, type_code~ : Int)
  InvalidValue(String)
  InvalidEnum(type_name~ : String, value~ : Int)
  MissingRequiredField(
    type_name~ : String,
    field_id~ : Int,
    field_name~ : String
  )
} derive(Debug, Eq)
