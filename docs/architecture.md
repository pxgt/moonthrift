# Architecture

MoonThrift separates schema tooling from protocol I/O so each layer can be
used independently.

```text
Thrift IDL -> lexer -> parser -> semantic checker -> linked schema workspace
                                                        |       |       |
                                                        |       |       +-> version compatibility
                                                        |       +-> typed MoonBit models/codecs
                                                        +-> dynamic protocol codecs
```

The root package owns source locations, tokens, the public IDL AST, parser,
diagnostics, semantic checking, and schema compatibility analysis. `protocol`
owns dynamic wire values, checked extraction helpers, binary/compact readers
and writers, and RPC message envelopes. `codegen` consumes a linked schema and
emits documented MoonBit declarations plus type-safe Binary/Compact adapters.
`cmd/main` is a thin native-only adapter for files, arguments, and exit codes.
The portable compatibility policy/report layer wraps the directional schema
diff and owns stable report ordering and formatting. The native CLI gathers
schema files and resolves includes. The optional Python Git adapter reads Git
objects into a temporary baseline; it does not implement compatibility rules.
The `rpc` package composes the portable Binary/Compact message codecs with a
byte-exchange callback and one-request handler. Its in-memory implementation
still serializes requests and responses. A separate bounded frame codec and
incremental decoder prepare complete messages for a stream adapter; the
native-only TCP tutorial is one example. Network I/O remains outside the
portable package. See [rpc-runtime.md](rpc-runtime.md)
for the boundary contract.
For non-inherited services, `codegen` also emits a typed client and handler
facade over this byte boundary. Mixed services use an optional-response byte
exchange: `CALL` requires a reply and `ONEWAY` forbids one. Inherited-service
facades still need method flattening and are not emitted.

## Functional boundary

Version 0.3.0 adds portable RPC message dispatch, generated service facades,
framed transport, and a native-only loopback TCP tutorial to the earlier
compiler and serialization substrate. It does not provide a reusable socket
transport API, long-running server loop, TLS, multiplexing, inherited-service
runtime facade, or every language-specific annotation used by upstream Thrift
generators. These require further runtime policy choices.

## Maintenance value

The AST and diagnostics support formatters, editors, schema linters, migration
tools, and custom generators. The dynamic protocol layer supports fixture
inspection and interoperability tests without generated code. Future transport
packages can build on the same checked schema and codecs rather than duplicate
the IDL and wire-format work.
