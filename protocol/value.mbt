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
} derive(Debug, Eq)
