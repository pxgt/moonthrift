# Changelog

All notable changes are recorded here. The format follows Keep a Changelog and
the project uses semantic versioning.

## [Unreleased]

## [0.3.0] - 2026-09-25

### Added

- A native-only framed TCP RPC tutorial and loopback integration test using
  generated service models, Binary/Compact protocols, and incremental framing.
- Bounded Apache Thrift framed transport with exact-frame codec and
  incremental decoder for fragmented or coalesced streams; reference Python
  `TFramedTransport` fixtures cover Binary and Compact RPC messages.
- Standard Thrift application-exception encode/decode with unknown-method,
  invalid-argument, and handler-failure envelopes across Binary and Compact.
- Generated `ONEWAY` client/handler facades with a no-response byte exchange;
  Apache Thrift Python cross-wire fixtures cover both new message paths.
- Generated typed request/reply clients and handler/processor facades for
  services without inheritance.
- Client-side sequence IDs, method dispatch, declared-result decoding, and
  decoded application-exception errors.
- A portable one-request RPC processor, byte-exchange client boundary, and
  synchronous in-memory transport for Binary and Compact messages.
- Generated service-model RPC round-trip tests and a runnable memory demo.
- Backward, forward, and full schema-compatibility policies, with exact rule
  suppression and deterministic text, JSON, Markdown, and GitHub annotations.
- File-tree comparison and a Git commit baseline adapter for schema PR checks.
- A reusable compatibility CI workflow and end-to-end CLI/Git baseline tests.

## [0.2.0] - 2026-09-20

### Added

- Portable multi-file schema workspaces with caller-provided source loading,
  normalized relative includes, deterministic traversal, and link diagnostics.
- Qualified cross-file type and service validation.
- IDL `uuid` and preserved container `cpp_type` metadata.
- Recursive multi-file `check` and `inspect` CLI workflows.
- Cycle diagnostics for typedefs and service inheritance.
- Collision-resistant single-file MoonBit model generation from a complete
  linked workspace.
- Checked protocol-value extraction helpers, including UTF-8 and container
  validation.
- Generated type-safe Binary and Compact adapters for enums, records,
  exceptions, unions, nested containers, and service argument/result models.
- Generated decoding semantics for optional fields, default values, unknown
  fields, missing required fields, and invalid enum values.
- Preservation of line and block IDL documentation in generated MoonBit APIs.
- Bidirectional Binary and Compact interoperability fixtures against Apache
  Thrift Python 0.24.0.
- Cross-language coverage for integer boundaries, Unicode, empty and nested
  containers, exceptions, and unknown fields.
- An independent Python interoperability CI job with deterministic fixture
  regeneration.

## [0.1.0] - 2026-09-16

### Added

- Source-aware Thrift IDL lexer, parser, AST, and semantic checker.
- Dynamic value model and bounded Binary/Compact protocol codecs.
- Strict binary and compact RPC message envelopes.
- MoonBit data-model code generator with compiled generated fixtures.
- Schema compatibility analysis for records, enums, constants, and services.
- Native `check`, `inspect`, `generate`, and `diff` CLI workflows.
- Four-backend tests, CI, architecture, protocol, and verification docs.
