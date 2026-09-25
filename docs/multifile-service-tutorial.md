# Multi-file service tutorial

This example starts from two Thrift IDL files, generates MoonBit types, and
runs a typed request/response exchange through both Binary and Compact.
It needs no running server, so the portable example works on all four stable
MoonBit backends.

## 1. Define and validate the schema

[`examples/multifile/common/types.thrift`](../examples/multifile/common/types.thrift)
defines `UserId` and `User`. The separate
[`examples/multifile/directory.thrift`](../examples/multifile/directory.thrift)
includes that file and uses both types in the `Directory.get_user` method.
From the repository root, run:

```sh
moon run cmd/main --target native -- check examples/multifile/directory.thrift
moon run cmd/main --target native -- inspect examples/multifile/directory.thrift
moon run cmd/main --target native -- generate \
  examples/multifile/directory.thrift examples/generated_directory/model.mbt
moon fmt examples/generated_directory/model.mbt
moon check examples/generated_directory --target all --deny-warn --warn-list +73-79
```

The generated model is checked into
[`examples/generated_directory/model.mbt`](../examples/generated_directory/model.mbt).
It includes the linked type, method argument/result codecs, a typed
`DirectoryClient`, and a `DirectoryHandler`. CI regenerates and compares it
byte-for-byte, so this example cannot silently drift from the generator.

## 2. Run the typed exchange

[`examples/directory_demo/main.mbt`](../examples/directory_demo/main.mbt)
implements a small handler and calls it through the generated client:

```sh
moon run examples/directory_demo --target wasm-gc
moon test examples/directory_demo --target all --deny-warn --warn-list +73-79
```

Expected output:

```text
Binary/memory: user 7 = Ada
Binary/framed: user 7 = Ada
Compact/memory: user 7 = Ada
Compact/framed: user 7 = Ada
```

The handler returns a `types.User` defined in the included file. The generated
client assigns sequence IDs and checks the response. The `framed` path adds
and removes a length prefix before and after the handler call. Tests also
verify that a failing handler becomes a standard RPC application exception.
This is an in-process exchange, not a TCP server: the separate
[`examples/tcp_demo`](../examples/tcp_demo) illustrates the native socket
adapter. Service inheritance is not flattened into typed runtime facades yet;
the existing `examples/multifile/api.thrift` deliberately continues to cover
inherited-service model generation only.

## 3. Check the published package from a separate module

[`examples/mooncakes_consumer`](../examples/mooncakes_consumer) has its own
`moon.mod` and pins `Xpeng/moonthrift@0.3.0`. Its executable parses an IDL
document and round-trips a value through both published codecs. It does not
import the checkout's source module or generated-directory package.

```sh
moon -C examples/mooncakes_consumer tree
moon -C examples/mooncakes_consumer check --target all --deny-warn --warn-list +73-79
moon -C examples/mooncakes_consumer test --target all --deny-warn --warn-list +73-79
moon -C examples/mooncakes_consumer run . --target wasm-gc
```

The final command prints:

```text
Mooncakes 0.3.0: parsed 1 definition; Binary and Compact round trips passed
```

This consumer is a regression check for package installation and public API
usability, not a substitute for the source-tree interoperability tests. The
version is intentionally pinned; updating it requires a deliberate dependency
change and another run of these checks.
