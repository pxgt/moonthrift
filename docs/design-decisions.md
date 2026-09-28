# Architecture decisions

These decisions describe the current `0.3.0` architecture and the tradeoffs
maintainers should preserve or explicitly revisit. They do not claim support
for deferred features.

## 1. Caller-owned source loading

**Decision:** The portable root package accepts a logical path and
`SourceLoader` callback for multi-file IDL, rather than opening files itself.
The native CLI supplies the filesystem adapter.

**Why:** The same parser and linker can run on wasm, wasm-gc, JavaScript, and
native, while include traversal and path normalization remain deterministic.
The tradeoff is that embedders must provide a loader and handle diagnostics.
Evidence: [workspace tests](../workspace_test.mbt),
[architecture](architecture.md), and [Phase 1 PR](https://github.com/pxgt/moonthrift/pull/5).

## 2. One wire model, optional typed generation

**Decision:** `protocol.Value` owns schema-independent Binary/Compact wire
data; `codegen` produces typed MoonBit wrappers that convert through that
model. Generated clients and handlers are emitted only for service shapes
whose dispatch is implemented, currently non-inherited services.

**Why:** Generic inspection and cross-language fixtures can use the same
codec as generated applications. It also keeps typed code out of the
portable codec package. The cost is allocation of the intermediate value
tree and the need to compile generated source. Inherited-service method
flattening remains separate work rather than a partial facade.
Evidence: [generated model tests](../examples/generated/model_test.mbt),
[multi-file service tutorial](multifile-service-tutorial.md), and
[API interfaces](public-api.md).

## 3. RPC is a byte boundary, not a network framework

**Decision:** The portable `rpc` package implements one-request dispatch,
message validation, an in-memory exchange, and bounded framing. Its callback
is synchronous. Native TCP appears only as a target-limited tutorial.

**Why:** Transport choice, scheduling, connection lifetime, security, and
backpressure belong to applications or future adapters. This leaves
four-backend RPC behavior testable without network access. The tutorial does
not promise a persistent or concurrent server. Evidence:
[RPC boundary](rpc-runtime.md), [native TCP demo](../examples/tcp_demo),
and [Phase 5 release](https://github.com/pxgt/moonthrift/releases/tag/v0.3.0).

## 4. Validate against an independent runtime and bounded inputs

**Decision:** Keep literal and Apache Thrift Python 0.24.0 wire fixtures,
four-backend tests, explicit decoder limits, a deterministic malformed-input
corpus, and an 85% core coverage floor. Benchmarks are observed performance
baselines, not hard CI thresholds.

**Why:** Encoder/decoder round trips alone can hide matching defects.
Bounded decoding reduces exposure to untrusted lengths and nesting. Fixed
seeds make failures reproducible, but do not replace a coverage-guided fuzzer.
Evidence: [interop matrix](interoperability.md),
[verification commands](verification.md), and [benchmarks](benchmarks.md).
