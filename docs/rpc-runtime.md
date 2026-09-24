# RPC runtime boundary

Phase 5 provides a synchronous, portable one-request path. It composes the
`protocol.Message` Binary/Compact codecs with application handlers and a
byte-exchange boundary. The `rpc` package imports only the portable `protocol`
package and runs on all four stable MoonBit backends.

```text
generated Client.method(Args) -> protocol.Message(CALL or ONEWAY)
  -> encode -> exchange(Bytes -> Bytes or Bytes?)
  -> generated Handler.serve_once -> decode and dispatch
  -> typed handler callback(Args) -> optional generated Result -> encode
  -> CALL: validate REPLY/EXCEPTION name and sequence ID, decode Result
  -> ONEWAY: no response is sent or decoded
```

`RpcProtocol` selects Binary or Compact; it does not own a transport.
`process_once` retains the original CALL-only `(Bytes) -> Bytes` API.
`process_once_optional` accepts CALL and ONEWAY, returning `Some(reply)` for
CALL and `None` for ONEWAY. `call_once` and `call_once_optional` likewise
offer required- and optional-response byte exchanges. `send_oneway` forbids
a reply. `MemoryTransport` retains the original request/reply interface for
tests and embedded applications.

For a non-inherited service, the generator emits a typed `ServiceClient` and a
`ServiceHandler` record of callbacks. The client assigns sequence IDs starting
at 1. Declared Thrift exceptions remain variants of the generated result enum.
The handler decodes arguments by method name, invokes the matching callback,
and preserves the request method and sequence ID in its reply. The generated
package must import `Xpeng/moonthrift/protocol` and `Xpeng/moonthrift/rpc`.

Services without ONEWAY methods retain the original `(Bytes) -> Bytes`
exchange and `serve_once(...) -> Bytes` API. A service with any ONEWAY method
uses `(Bytes) -> Bytes?` and `serve_once(...) -> Bytes?`: a CALL must produce
`Some(reply)` and ONEWAY must produce `None`. A typed ONEWAY client method
returns `Unit` and does not decode a result.

The runtime rejects invalid message kinds, response kinds other than REPLY
or EXCEPTION, and mismatched method names or sequence IDs. Message decoders
enforce wire-format limits and reject trailing data. An unknown CALL method
returns a standard `TApplicationException` payload (type 1); malformed typed
arguments return type 7, and a callback failure returns type 6. The typed
client decodes an EXCEPTION envelope into
`ProtocolError::ApplicationException(message, type_code)` instead of treating
it as a declared result. Unknown ONEWAY methods produce no reply. A local
ONEWAY callback may still raise to its host; it never generates wire output.

Run the in-memory demo from the repository root:

```sh
moon run examples/rpc_demo --target native
```

It creates a generated `UserDirectoryHandler` and `UserDirectoryClient` around
a Compact byte exchange. Four-backend tests also cover Binary, sequential
client calls, declared and application exceptions, unknown methods, mixed
CALL/ONEWAY dispatch, and invalid envelopes. Independent Apache Thrift Python
fixtures verify EXCEPTION and ONEWAY bytes in both codecs.

Not yet implemented: inherited-service runtime facades, framed transport,
TCP, async I/O, multiplexing, or a persistent server loop. No partial runtime
facade is emitted for inherited services. The byte-exchange callback is
synchronous by design; target-specific async/TCP adapters belong in separate
packages.
