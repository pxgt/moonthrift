# Changelog

All notable changes are recorded here. The format follows Keep a Changelog and
the project uses semantic versioning.

## [Unreleased]

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

## [0.1.0] - 2026-09-16

### Added

- Source-aware Thrift IDL lexer, parser, AST, and semantic checker.
- Dynamic value model and bounded Binary/Compact protocol codecs.
- Strict binary and compact RPC message envelopes.
- MoonBit data-model code generator with compiled generated fixtures.
- Schema compatibility analysis for records, enums, constants, and services.
- Native `check`, `inspect`, `generate`, and `diff` CLI workflows.
- Four-backend tests, CI, architecture, protocol, and verification docs.
