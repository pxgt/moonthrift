# RPC runtime boundary

Phase 5 starts with a synchronous, portable one-request path. It composes the
existing `protocol.Message` Binary/Compact codecs with an application handler
and a byte-exchange boundary. The `rpc` package imports only the portable
`protocol` package and runs on all four stable MoonBit backends.

```text
generated Client.method(Args) -> protocol.Message(CALL) -> rpc.call_once
  -> encode -> exchange(Bytes -> Bytes)
  -> generated Handler.serve_once -> rpc.process_once -> decode
  -> typed handler callback(Args) -> generated Result -> encode
  -> decode -> validate REPLY/EXCEPTION name and sequence ID
  -> generated Client decodes Result
```

`RpcProtocol` selects Binary or Compact; it does not own a transport.
`process_once` accepts encoded bytes and a handler that maps one decoded
`Message` to one response `Message`. `call_once` accepts any byte-exchange
callback, so future framed TCP or other adapters can supply I/O without
changing the protocol codec or generated service models. `MemoryTransport`
connects these two functions in-process and still serializes both sides,
making it useful for tests and embedded applications.

For a service without inheritance or `ONEWAY` methods, the generator emits a
`ServiceClient` with typed methods and a `ServiceHandler` record of typed
callbacks. The client assigns sequence IDs starting at 1, calls through a
byte-exchange callback, and decodes the existing generated result enum.
Declared Thrift exceptions are variants of that result enum. The handler
decodes arguments by method name, invokes the matching callback, and preserves
the request method and sequence ID in its reply. It also exposes
`serve_once` for byte-oriented transports. The generated package must import
both `Xpeng/moonthrift/protocol` and `Xpeng/moonthrift/rpc`.

This increment rejects non-`CALL` requests, response kinds other than `REPLY`
or `EXCEPTION`, and mismatched method names or sequence IDs. Existing message
decoders enforce wire-format limits and reject trailing data. Application
handlers may return `ProtocolError`; converting unknown methods and other
handler failures into Thrift application-exception envelopes is later work.
An unknown method currently raises `InvalidMessage`. A received application
`EXCEPTION` envelope is detected by the typed client and rejected explicitly
rather than being misdecoded as a declared result.

The executable example can be run from the repository root:

```sh
moon run examples/rpc_demo --target native
```

It creates a generated `UserDirectoryHandler` and `UserDirectoryClient`
around a Compact byte exchange. The four-backend tests also cover Binary,
sequential client calls, a declared service exception, unknown methods,
application-exception detection, and invalid request/reply envelopes.

Not yet implemented: `ONEWAY`, inherited-service runtime facades,
application-exception serialization, framed transport, TCP, async I/O,
multiplexing, or a persistent server loop. No partial runtime facade is emitted
for an inherited or oneway service. The byte-exchange callback is synchronous
by design; target-specific async/TCP adapters belong in separate packages.
