# MoonThrift

MoonThrift is a MoonBit implementation of the language-neutral parts of
[Apache Thrift](https://thrift.apache.org/): IDL parsing and validation,
dynamic values, binary and compact protocol codecs, and MoonBit source
generation. It is designed for build tools, schema inspection, data migration,
and future RPC runtimes that need one reusable Thrift foundation.

The first release is intentionally transport-independent. It handles schemas
and wire-format payloads without choosing an HTTP, socket, or async runtime.
That boundary keeps the core portable across MoonBit's stable backends.

## Planned 0.1.0 surface

- Parse Thrift IDL headers, constants, typedefs, enums, structs, unions,
  exceptions, and services.
- Validate duplicate names and field IDs, unresolved named types, union rules,
  and service inheritance.
- Encode and decode dynamic values with the standard binary and compact
  protocols.
- Generate readable MoonBit declarations from a checked schema.
- Provide a native CLI for `check`, `inspect`, and `generate` workflows.

The implementation status and runnable commands will be kept here as the
milestones land. See [the architecture note](docs/architecture.md) for the
package boundaries and explicit non-goals.

## License

MoonThrift is licensed under Apache-2.0. Apache Thrift is an independent
Apache Software Foundation project; MoonThrift is not endorsed by ASF. See
[THIRD_PARTY.md](THIRD_PARTY.md) for the compatibility and provenance notes.
