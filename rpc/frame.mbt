///|
/// Apache Thrift's standard framed-transport maximum in bytes.
pub let default_max_frame_size : Int = 16384000

///|
fn validate_frame_limit(
  max_frame_size : Int,
) -> Unit raise @protocol.ProtocolError {
  if max_frame_size < 0 || max_frame_size > default_max_frame_size {
    raise InvalidValue("frame limit must be between 0 and 16384000 bytes")
  }
}

///|
fn frame_length(
  first : Byte,
  second : Byte,
  third : Byte,
  fourth : Byte,
  max_frame_size : Int,
) -> Int raise @protocol.ProtocolError {
  let raw : UInt = (first.to_uint() << 24) |
    (second.to_uint() << 16) |
    (third.to_uint() << 8) |
    fourth.to_uint()
  let length = raw.reinterpret_as_int()
  if length < 0 {
    raise NegativeSize(length)
  }
  if length > max_frame_size {
    raise LimitExceeded(kind="frame", limit=max_frame_size, actual=length)
  }
  length
}

///|
/// Prefixes one complete message with a signed, big-endian 32-bit length.
/// Empty frames are valid; an RPC message inside a frame is never empty.
pub fn encode_frame(
  payload : Bytes,
  max_frame_size? : Int = default_max_frame_size,
) -> Bytes raise @protocol.ProtocolError {
  validate_frame_limit(max_frame_size)
  if payload.length() > max_frame_size {
    raise LimitExceeded(
      kind="frame",
      limit=max_frame_size,
      actual=payload.length(),
    )
  }
  let buffer = @buffer.Buffer()
  buffer.write_int_be(payload.length())
  buffer.write_bytes(payload)
  buffer.to_bytes()
}

///|
/// Decodes exactly one complete frame. Truncation and trailing bytes are
/// rejected; use `FrameDecoder` when reading an arbitrary byte stream.
pub fn decode_frame(
  frame : Bytes,
  max_frame_size? : Int = default_max_frame_size,
) -> Bytes raise @protocol.ProtocolError {
  validate_frame_limit(max_frame_size)
  if frame.length() < 4 {
    raise UnexpectedEof(offset=0, needed=4)
  }
  let length = frame_length(
    frame[0],
    frame[1],
    frame[2],
    frame[3],
    max_frame_size,
  )
  let remaining = frame.length() - 4
  if remaining < length {
    raise UnexpectedEof(offset=4, needed=length)
  }
  if remaining > length {
    raise TrailingData(offset=4 + length, remaining=remaining - length)
  }
  frame[4:4 + length].to_owned()
}

///|
/// Incrementally decodes a stream of framed messages. It accepts arbitrary
/// chunk boundaries and can return multiple complete payloads per chunk.
pub struct FrameDecoder {
  max_frame_size : Int
  header : Array[Byte]
  mut body : @buffer.Buffer
  mut expected : Int
  mut received : Int
}

///|
pub fn FrameDecoder::new(
  max_frame_size? : Int = default_max_frame_size,
) -> FrameDecoder raise @protocol.ProtocolError {
  validate_frame_limit(max_frame_size)
  { max_frame_size, header: [], body: Buffer(), expected: -1, received: 0, }
}

///|
fn FrameDecoder::reset(self : FrameDecoder) -> Unit {
  self.header.clear()
  self.body = Buffer()
  self.expected = -1
  self.received = 0
}

///|
/// Adds the next stream chunk and returns all frames completed by it.
/// An invalid length raises before allocating its declared body size.
pub fn FrameDecoder::push(
  self : FrameDecoder,
  chunk : Bytes,
) -> Array[Bytes] raise @protocol.ProtocolError {
  let frames : Array[Bytes] = []
  let mut offset = 0
  while offset < chunk.length() {
    if self.expected < 0 {
      let needed = 4 - self.header.length()
      let take = if chunk.length() - offset < needed {
        chunk.length() - offset
      } else {
        needed
      }
      for index in offset..<(offset + take) {
        self.header.push(chunk[index])
      }
      offset += take
      if self.header.length() == 4 {
        errdefer self.reset()
        self.expected = frame_length(
          self.header[0],
          self.header[1],
          self.header[2],
          self.header[3],
          self.max_frame_size,
        )
        if self.expected == 0 {
          frames.push(b"")
          self.reset()
        }
      }
    } else {
      let needed = self.expected - self.received
      let take = if chunk.length() - offset < needed {
        chunk.length() - offset
      } else {
        needed
      }
      self.body.write_bytes(chunk[offset:offset + take])
      self.received += take
      offset += take
      if self.received == self.expected {
        frames.push(self.body.to_bytes())
        self.reset()
      }
    }
  }
  frames
}

///|
/// True when the decoder holds an incomplete header or body.
pub fn FrameDecoder::has_pending(self : FrameDecoder) -> Bool {
  self.header.length() > 0
}
