# Public API guide

This page is an entry map, not a duplicate of every generated signature.
The authoritative inventories are the checked-in
[IDL](../pkg.generated.mbti), [protocol](../protocol/pkg.generated.mbti),
[codegen](../codegen/pkg.generated.mbti), and [RPC](../rpc/pkg.generated.mbti)
interfaces. Run `moon ide doc '@moonthrift.compile_workspace'` (or another
symbol) against your installed dependency to check the API of that version.
The examples below use the `Xpeng/moonthrift@0.3.1` API. This maintenance
release adds the Phase 6 tests, examples, and documentation without changing
the public interfaces listed above. The independent regression consumer in
this repository intentionally remains pinned to `0.3.0`.

## Choose a package

| Package | Start here | Failure boundary |
| --- | --- | --- |
| `Xpeng/moonthrift` | `parse_idl`, `compile_idl`, `compile_workspace`, `compare_schemas_with_policy` | Lexical/syntax failures raise `IdlError`; semantic and linking problems are `Diagnostic` values. |
| `Xpeng/moonthrift/protocol` | `Value`, `encode_binary` / `decode_binary`, `encode_compact` / `decode_compact` | Invalid values, wire bytes, and configured limits raise `ProtocolError`. |
| `Xpeng/moonthrift/codegen` | `generate_moonbit`, `generate_workspace` | Produces a `GeneratedFile`; compile its `content` as a separate MoonBit package. |
| `Xpeng/moonthrift/rpc` | `RpcProtocol`, `call_once`, `process_once`, `encode_frame`, `FrameDecoder` | A synchronous byte-exchange boundary; no portable socket runtime is implied. |

Add the module dependency with `moon add Xpeng/moonthrift@0.3.1`. A consuming
package imports only the packages it calls in its `moon.pkg`:

```moonbit
import {
  "Xpeng/moonthrift",
  "Xpeng/moonthrift/protocol",
  "Xpeng/moonthrift/codegen",
  "Xpeng/moonthrift/rpc",
}
```

The [independent consumer](../examples/mooncakes_consumer) uses a smaller
two-package import and is continuously compiled against the published module.

## IDL and code generation

`parse_idl(text)` parses one document. `compile_idl(text)` also returns
semantic diagnostics. For an include graph, pass a logical root path and a
caller-owned `(String) -> String?` loader to `compile_workspace`. The loader
receives normalized paths; missing includes and linking failures become
diagnostics rather than implicit filesystem access. Check the returned
diagnostics before using the workspace. See the runnable
[workspace test](../workspace_test.mbt) and
[multi-file tutorial](multifile-service-tutorial.md).

Pass a validated `SchemaWorkspace` to
`@codegen.generate_workspace(workspace)`. Its `GeneratedFile.content` is
MoonBit source, not a runtime-compiled object. The generated package imports
`protocol`, and imports `rpc` when it contains supported service facades.
The repository compiles checked-in generated models on all stable backends
and compares regenerated source in CI. Runtime facades are emitted for
non-inherited services; inherited services currently receive models only.

## Values, wire data, and RPC

`protocol.Value` is a schema-independent tree retaining field IDs and
container types. Use `encode_binary` / `decode_binary` or their Compact
counterparts when generated types are unnecessary. Decoders take the expected
`WireType` and optional depth, container-size, and binary-size limits.
The [published consumer](../examples/mooncakes_consumer/main.mbt) exercises
both codecs; [protocol notes](protocols.md) specify the wire details and
default limits. A `Value` is not a substitute for validating an IDL schema
when field-level compatibility matters.

`rpc.RpcProtocol` selects a message codec, while `call_once` and
`process_once` accept application-supplied byte callbacks. Generated service
clients and handlers sit on that boundary. `encode_frame`,
`decode_frame`, and `FrameDecoder` handle length-prefixed streams without
owning a socket. The [RPC boundary guide](rpc-runtime.md) explains CALL,
ONEWAY, declared versus application exceptions, and limits; the
[directory demo](../examples/directory_demo/main.mbt) runs both protocols
with and without framing.

## Schema evolution and integration

`compare_schemas_with_policy(old, new, policy)` returns directional findings
under `Backward`, `Forward`, or `Full`. Render text, JSON, Markdown, or
GitHub annotations with `render_compatibility_report`. The native CLI and
`tools/compat_git.py` add file/directory/Git-baseline I/O around these portable
functions; see [compatibility CI](compatibility-ci.md). Other native-only
adapters live under `cmd/main` or examples, not in the four-backend core.

For a complete validation sequence, use [verification.md](verification.md).
The package's tested scope and deliberate exclusions are listed in
[architecture.md](architecture.md); generated interfaces should be reviewed
whenever a public MoonBit declaration changes.
