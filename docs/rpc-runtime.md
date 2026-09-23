# RPC runtime boundary

Phase 5 starts with a synchronous, portable one-request path. It composes the
existing `protocol.Message` Binary/Compact codecs with an application handler
and a byte-exchange boundary. The `rpc` package imports only the portable
`protocol` package and runs on all four stable MoonBit backends.

```text
generated Args -> protocol.Message(CALL) -> rpc.call_once
  -> encode -> exchange(Bytes -> Bytes)
  -> rpc.process_once -> decode -> application handler -> encode
  -> decode -> validate REPLY/EXCEPTION name and sequence ID
  -> generated Result
```

`RpcProtocol` selects Binary or Compact; it does not own a transport.
`process_once` accepts encoded bytes and a handler that maps one decoded
`Message` to one response `Message`. `call_once` accepts any byte-exchange
callback, so future framed TCP or other adapters can supply I/O without
changing the protocol codec or generated service models. `MemoryTransport`
connects these two functions in-process and still serializes both sides,
making it useful for tests and embedded applications.

This increment rejects non-`CALL` requests, response kinds other than `REPLY`
or `EXCEPTION`, and mismatched method names or sequence IDs. Existing message
decoders enforce wire-format limits and reject trailing data. Application
handlers may return `ProtocolError`; converting unknown methods and other
handler failures into Thrift application-exception envelopes is later work.

The executable example can be run from the repository root:

```sh
moon run examples/rpc_demo --target native
```

It uses the generated `UserDirectoryGetUserArgs` and
`UserDirectoryGetUserResult` models across a Compact message exchange. The
four-backend tests also cover Binary, a declared service exception, and
invalid request/reply envelopes.

Not yet implemented: `ONEWAY`, generated typed client/handler/processor
facades, application-exception serialization, framed transport, TCP, async
I/O, multiplexing, or a persistent server loop. The byte-exchange callback is
synchronous by design for this first increment; target-specific async/TCP
adapters belong in separate packages.
