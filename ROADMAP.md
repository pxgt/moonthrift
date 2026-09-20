# Roadmap

The detailed award-oriented execution plan and live progress ledger are kept in
[docs/award-roadmap.md](docs/award-roadmap.md). This file remains the concise
public summary.

## 0.1 series

- Expand official Apache Thrift conformance fixtures and compare outputs with
  one maintained upstream implementation.
- Resolve include graphs through a caller-provided source loader.
- Generate codec adapters alongside MoonBit data declarations.
- Preserve doc comments and more language-specific annotations.

## Later exploration

- Framed and buffered transports as separate native/async packages.
- Client/server dispatch generation without coupling the portable core to one
  networking runtime.
- Language Server Protocol features built on the source-aware AST.
- Additional generators driven by the same checked schema.

Transport and RPC runtime work will be proposed separately so the core package
keeps a clear, maintainable boundary.
