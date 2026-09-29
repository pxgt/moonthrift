# Changelog

All notable changes are recorded here. The format follows Keep a Changelog and
the project uses semantic versioning.

## [Unreleased]

### Documentation

- README shows how to run the published CLI with `moonx` without cloning the
  repository (verified with `check` and `generate` on 0.4.0).

## [0.4.0] - 2026-09-30

### Added

- The CLI (`cmd/main`) now supports the `wasm` and `wasm-gc` backends in
  addition to `native`, so it no longer needs a C compiler. `generate` output
  is byte-identical across backends, and CI exercises the wasm CLI.
- A feature-support matrix in the README that states what is and is not
  implemented, and a refreshed "current boundaries" section.
- `WireType::Uuid`, `Value::UuidValue(Bytes)` and `Value::require_uuid`:
  `uuid` is now encoded exactly as Apache Thrift 0.19+ does (Binary type 16,
  Compact type 13, 16 raw bytes with no length prefix), including inside
  structs, lists, sets, and maps. Fixed byte sequences from Apache Thrift
  Python 0.24.0 and bidirectional interoperability tests for an `Inventory`
  record with `uuid` and `list<uuid>` fields cover the new format.

### Changed

- **Wire-format behavior change for `uuid`.** MoonThrift 0.3.1 and earlier
  wrote `uuid` as length-prefixed `binary`, which did not interoperate with
  Apache Thrift: a uuid written by Apache Thrift failed to decode with
  `InvalidType`, even when the field was only being skipped. Exchanging `uuid`
  fields with a MoonThrift <= 0.3.1 peer is therefore not symmetric: the old
  peer rejects the new type ID as an unknown type, while the new version can still read the old format
  because `Value::require_uuid` also accepts a 16-byte `BinaryValue`. Generated
  code decodes uuid through `require_uuid` and exposes uuid fields as `Bytes`,
  as before. `WireType` and `Value` gained a variant, so exhaustive `match`
  expressions over them need a new arm.
- Migrated all 111 `[0079]` (`implicit_impl_as_method`) warnings reported by
  MoonBit 0.10.14 using hidden, deprecated `pub extend` declarations in each
  package's `deprecated.mbt`. Generated code now emits the same declarations
  for every public type. Public interfaces (`.mbti`) are unchanged, and CI no
  longer exempts any warning (`--warn-list +73-79` became `--warn-list +73`).

### Fixed

- Generated code no longer fails to compile for enums nested in `list`, `set`
  or `map` values (decoded through the generated `Enum::from_thrift_value`),
  enums used as `map` keys (generated enums now also derive `Hash`), and empty
  structs (which now derive `Debug` and `Eq`, so records, lists and services
  containing them compile). The new `examples/containers.thrift` and
  `examples/generated_containers` package cover all three cases, and CI
  regenerates and compares it byte for byte.

### Known limitations

- `uuid` constants and field defaults are not supported: the generator emits the
  36-character text, not 16 bytes.

## [0.3.1] - 2026-09-29

### Added

- Core-package line coverage enforcement above 85%, with focused protocol and
  generator edge-case tests.
- Fixed-seed Binary/Compact round-trip properties, malformed wire input, and
  mutated IDL regression corpora.
- Reproducible parser and protocol microbenchmarks, with a recorded release-mode
  wasm-gc baseline and CI compilation on all stable backends.
- A generated multi-file service tutorial and an independent Mooncakes
  `0.3.0` consumer module, both exercised in CI.
- Public API guidance, architecture-decision records, and a source-to-CI
  release/maintenance evidence ledger.
- A single-command, CI-checked judging demonstration spanning multi-file IDL,
  deterministic generation, typed RPC, schema evolution, and Mooncakes use.

This release packages the Phase 6 work already merged to `main`. It does not
change the public MoonBit API or the supported protocol behavior of `0.3.0`.

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
