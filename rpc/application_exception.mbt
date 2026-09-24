///|
/// Standard Apache Thrift application exception payload. Unknown numeric
/// codes are retained so a newer peer can still be diagnosed.
pub(all) struct ApplicationException {
  message : String
  type_code : Int
} derive(Debug, Eq)

///|
/// Serializes the two standard fields of TApplicationException.
pub fn ApplicationException::to_thrift_value(
  self : ApplicationException,
) -> @protocol.Value {
  StructValue([
    { id: 1, value: @protocol.string_value(self.message), },
    { id: 2, value: I32Value(self.type_code), },
  ])
}

///|
/// Decodes a TApplicationException, preserving its numeric type code.
pub fn ApplicationException::from_thrift_value(
  value : @protocol.Value,
) -> ApplicationException raise @protocol.ProtocolError {
  let fields = value.require_struct()
  let message = match @protocol.find_field(fields, 1) {
    Some(value) => value.require_string()
    None => ""
  }
  let type_code = match @protocol.find_field(fields, 2) {
    Some(value) => value.require_i32()
    None => 0
  }
  { message, type_code, }
}

///|
/// Builds an EXCEPTION response with the request's method and sequence ID.
pub fn application_exception_reply(
  request : @protocol.Message,
  type_code : Int,
  message : String,
) -> @protocol.Message {
  {
    name: request.name,
    kind: Exception,
    sequence_id: request.sequence_id,
    body: ({ message, type_code, } : ApplicationException).to_thrift_value(),
  }
}

///|
/// Returns a successful reply body or raises its remote application
/// exception. The transport layer checks method and sequence ID first.
pub fn reply_result_body(
  reply : @protocol.Message,
) -> @protocol.Value raise @protocol.ProtocolError {
  if reply.kind is Reply {
    return reply.body
  }
  if !(reply.kind is Exception) {
    raise InvalidMessage("RPC message is not a reply")
  }
  let exception = ApplicationException::from_thrift_value(reply.body)
  raise ApplicationException(
    message=exception.message,
    type_code=exception.type_code,
  )
}
