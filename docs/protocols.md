# Protocol implementation notes

MoonThrift implements Apache Thrift's standard binary and compact wire
protocols over a schema-independent `Value` tree. The value tree deliberately
stores container element types and struct field IDs because those facts exist
on the wire and are required for lossless inspection.

## Binary protocol

Integers and doubles use fixed-width big-endian encoding. Strings and binary
values use a signed 32-bit byte length. Struct fields contain a type byte and a
signed 16-bit field ID and terminate with `STOP`. Containers carry their element
type(s) and signed 32-bit count.

Strict RPC messages use version `0x8001`, a message type, UTF-8 method name,
sequence ID, and struct body. The non-versioned legacy message form is not
accepted because it is ambiguous and commonly disabled in production stacks.

## Compact protocol

Signed integers use zigzag plus unsigned varint encoding. Doubles are
little-endian. Field IDs use delta encoding when the next ID is within 1–15;
boolean field values are carried in the field type nibble. Small list/set sizes
are packed into the collection header. RPC envelopes validate protocol ID
`0x82` and version 1.

## UUID wire format

Apache Thrift 0.19 and later define `uuid` as its own type rather than a
`binary` alias. MoonThrift follows that definition since 0.4.0:

| Protocol | Type ID | Payload |
|---|---|---|
| Binary | 16 | exactly 16 raw bytes, no length prefix |
| Compact | 13 | exactly 16 raw bytes, no length prefix |

The 16 bytes are in RFC 4122 (big-endian) order, so
`00112233-4455-6677-8899-aabbccddeeff` is written as `00 11 22 ... ee ff`.
`Value::UuidValue(Bytes)` carries the payload and `WireType::Uuid` its type.
Encoders raise `InvalidValue` unless the payload is exactly 16 bytes, decoders
raise `UnexpectedEof` on truncated input, and uuid values work inside structs,
lists, sets, and maps. `Value::require_uuid` also accepts a 16-byte
`BinaryValue`, because MoonThrift 0.3.1 and earlier wrote uuid as
length-prefixed binary; the reverse is not true, so a 0.3.1 peer rejects the new
type ID as unknown. Generated MoonBit still exposes uuid fields as `Bytes`.

The literal fixtures below come from Apache Thrift Python 0.24.0 for a struct
whose field 1 is a uuid and whose field 2 is a one-element `list<uuid>`, and
are asserted byte for byte in `protocol/uuid_test.mbt`:

```text
Binary:  10 00 01 <16 bytes> 0f 00 02 10 00 00 00 01 <16 bytes> 00
Compact: 1d <16 bytes> 19 1d <16 bytes> 00
```

## Defensive limits

Both decoders accept labeled limits for nesting depth, container length, and
binary length. Defaults are 64 levels, 1,000,000 elements, and 16 MiB. Negative
binary-protocol sizes, oversized compact varints, truncated payloads, invalid
type IDs, malformed message headers, type mismatches, and trailing bytes return
`ProtocolError`; they do not intentionally panic or allocate from an unchecked
wire size.

## Stable fixtures

Tests include literal byte fixtures rather than only round trips. For example,
the struct `{1: i32 42, 2: binary "Ada", 3: bool true}` encodes as:

```text
Binary:  08 00 01 00 00 00 2a 0b 00 02 00 00 00 03 41 64 61 02 00 03 01 00
Compact: 15 54 18 03 41 64 61 11 00
```

These fixtures make byte-order and field-header regressions visible even when
an encoder and decoder contain the same bug.
