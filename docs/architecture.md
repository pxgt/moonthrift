# Architecture

MoonThrift separates schema tooling from protocol I/O so each layer can be
used independently.

```text
Thrift IDL -> lexer -> parser -> semantic checker -> checked schema
                                                     |       |       |
                                                     |       |       +-> version compatibility
                                                     |       +-> MoonBit generator
                                                     +-> dynamic protocol codecs
```

The root package owns source locations, tokens, the public IDL AST, parser,
diagnostics, semantic checking, and schema compatibility analysis. `protocol`
owns dynamic wire values, binary/compact readers and writers, and RPC message
envelopes. `codegen` consumes a checked schema and emits MoonBit declarations.
`cmd/main` is a thin native-only adapter for files, arguments, and exit codes.

## Functional boundary

Version 0.1.0 targets the reusable compiler and serialization substrate. It
does not implement a socket transport, server loop, service dispatch runtime,
TLS, multiplexing, or every language-specific annotation used by upstream
Thrift generators. Those features require runtime policy choices and are kept
outside the portable core.

## Maintenance value

The AST and diagnostics support formatters, editors, schema linters, migration
tools, and custom generators. The dynamic protocol layer supports fixture
inspection and interoperability tests without generated code. Future transport
packages can build on the same checked schema and codecs rather than duplicate
the IDL and wire-format work.
