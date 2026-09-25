# MoonThrift Award Roadmap

This document is the execution baseline for developing MoonThrift from its
`0.1.0` compiler/protocol foundation into a mature, practical, and extensible
MoonBit Thrift toolchain. It is also the hand-off record for future maintainers
and coding agents.

## Product goal

MoonThrift should support this complete workflow:

```text
multi-file Thrift IDL
  -> parse and link schemas
  -> validate semantics and compatibility
  -> generate typed MoonBit models and codecs
  -> interoperate through Binary/Compact protocols
  -> generate service clients/processors
  -> run in CI and real applications
```

The core packages remain portable across wasm, wasm-gc, JavaScript, and native.
Filesystem and network adapters belong in explicitly target-limited packages.

## Current status

- Current release: `0.3.0`
- Current development branch: `main`
- Completed milestone: Phase 5 — RPC runtime and `0.3.0` ([Issue #26](https://github.com/pxgt/moonthrift/issues/26), [release](https://github.com/pxgt/moonthrift/releases/tag/v0.3.0))
- Next milestone: Phase 6 — hardening and presentation
- Phase 1 evidence: [Issue #4](https://github.com/pxgt/moonthrift/issues/4),
  [PR #5](https://github.com/pxgt/moonthrift/pull/5), and
  [main CI](https://github.com/pxgt/moonthrift/actions/runs/35481230921)
- Last updated: 2026-09-25

Status legend: `[ ]` planned, `[-]` active, `[x]` complete.

## Phase 1 — multi-file schema workspace

Target: portable loading/linking foundation for `0.2.0`.

- [x] Add a caller-provided source loader and public `SchemaWorkspace` model.
- [x] Normalize portable relative include paths.
- [x] Recursively load includes once in deterministic order.
- [x] Diagnose missing sources, include cycles, and conflicting include aliases.
- [x] Validate qualified types and service inheritance across direct includes.
- [x] Add `uuid` and parse/preserve container `cpp_type` metadata.
- [x] Detect typedef and service-inheritance cycles.
- [x] Add focused black-box tests and update generated interfaces.
- [x] Integrate the workspace API into native CLI `check`, `inspect`, and
  `generate` workflows.

Exit gate:

- Existing single-file public APIs remain available.
- A multi-file example passes `check`, `inspect`, and `generate`.
- Format, interface generation, check, build, and tests pass on all four stable
  backends.

## Phase 2 — typed MoonBit codec generation

- [x] Generate Binary and Compact encode/decode adapters for records.
- [x] Implement required, optional, and default-value semantics.
- [x] Skip unknown fields and reject missing required fields deterministically.
- [x] Generate enum, union, exception, container, and nested-type adapters.
- [x] Generate service argument/result codecs.
- [x] Preserve IDL documentation as MoonBit doc comments.
- [x] Compile and execute generated codecs on every stable backend.

Exit gate: generated MoonBit values complete Binary/Compact round trips without
manually constructing the dynamic `protocol.Value` tree.

## Phase 3 — cross-language interoperability and `0.2.0`

- [x] Establish Apache Thrift Python as the first reference implementation.
- [x] Test Python encode -> MoonBit decode and MoonBit encode -> Python decode.
- [x] Cover Binary and Compact protocols, integer boundaries, Unicode, empty and
  nested containers, exceptions, and unknown fields.
- [x] Add licensed upstream fixtures with provenance in `THIRD_PARTY.md`.
- [x] Run interoperability as an independent CI job.
- [x] Publish Mooncakes `0.2.0`, annotated tag, and GitHub release.

## Phase 4 — compatibility CI

- [x] Support backward, forward, and full compatibility policies.
- [x] Add stable text and JSON output.
- [x] Add GitHub Actions annotations.
- [x] Support rule suppression and file/directory/Git baselines.
- [x] Generate Markdown compatibility reports.
- [x] Provide a reusable CI example that rejects a breaking schema PR.

## Phase 5 — RPC runtime and `0.3.0`

- [x] Define protocol/transport boundaries without coupling the portable core
  to one I/O runtime.
- [x] Implement an in-memory transport and request/response processor.
- [x] Generate typed client, handler, and processor interfaces for ordinary
  request/reply services.
- [x] Handle sequence IDs, declared exceptions, application exceptions, oneway
  calls, and unknown methods.
- [x] Add framed transport.
- [x] Add a native TCP tutorial as a target-limited adapter.
- [x] Publish Mooncakes `0.3.0`, annotated tag, and GitHub release.

## Phase 6 — hardening and presentation

- [ ] Reach at least 85% measurable coverage in core packages.
- [ ] Add randomized round-trip/property tests and malformed-input fuzz cases.
- [ ] Publish parser and protocol benchmarks.
- [ ] Provide a complete multi-file service tutorial and an independent
  Mooncakes consumer project.
- [ ] Maintain API documentation, architecture decisions, changelog, Issues,
  PRs, CI evidence, and reproducible release records.
- [ ] Prepare a short end-to-end demonstration for quarterly judging.

## Deferred work

The following items are intentionally deferred until the core `0.3.0` workflow
is complete: LSP/editor integration, GUI tools, TLS, connection pooling, JSON
Protocol, and generators for languages other than MoonBit.

## Engineering rules

Every phase uses an Issue, a focused branch, meaningful commits, a reviewed PR,
green CI, and a clean merge back to `main`. New public APIs require black-box
tests and reviewed `pkg.generated.mbti` changes. Each implementation increment
must run the narrowest relevant tests first and finish with:

```sh
moon fmt --check
moon info --target all
moon check --target all --deny-warn --warn-list +73-79
moon build --target all
moon test --target all --deny-warn --warn-list +73-79
moon package --frozen
git diff --exit-code
```

## Progress log

- 2026-09-19: Roadmap confirmed after initial-review acceptance. Phase 1 issue
  and branch created; schema workspace implementation started.
- 2026-09-20: Added the portable workspace loader/linker, include diagnostics,
  qualified-reference checks, UUID/`cpp_type` parsing, multi-file CLI checks,
  cycle analysis, workspace-aware generation, and four-backend regression
  coverage. PR #5 was merged after branch CI passed; the resulting `main` CI
  also passed all checks. Phase 1 is complete and Phase 2 is next.
- 2026-09-20: Started Phase 2 in Issue #7. Added checked dynamic-value
  extraction and generated type-safe Binary/Compact adapters for records,
  enums, unions, exceptions, nested containers, and service models. Generated
  fixtures now execute four-backend round trips; documentation-comment
  preservation was the final open item before the Phase 2 exit gate.
- 2026-09-20: Preserved line and block IDL documentation on constants,
  typedefs, enums and members, records and fields, unions, services, and
  functions. Phase 2 now satisfies its exit gate with 36 tests on each stable
  backend; PR #8 records the review and CI evidence.
- 2026-09-20: Started Phase 3 in Issue #9. Pinned Apache Thrift Python 0.24.0,
  added deterministic Binary/Compact reference fixtures and four-backend
  bidirectional tests, and documented fixture provenance and reproduction.
- 2026-09-20: PR #10 passed the regular and independent interoperability CI
  jobs and was merged. Mooncakes 0.2.0 built successfully, annotated tag
  `v0.2.0` and the GitHub release were published, and Phase 3 was completed.
- 2026-09-20: MoonBit 2026-09-20 added derived-method warning 079. CI was
  updated for the new black-box test qualification rule; the broader explicit
  trait-method export migration is tracked in Issue #13.
- 2026-09-23: Phase 4 implementation started in Issue #14. Portable policy
  comparison and report rendering, native file/directory comparison, Git
  baseline extraction, integration tests, and a reusable PR workflow are in
  PR #15. Branch CI passed all four backends, interoperability, CLI/Git
  baseline tests, and the PR compatibility gate. Phase 4 is complete after
  the reviewed merge and green main CI.
- 2026-09-23: Phase 5 opened in Issue #16. A portable byte-exchange boundary,
  single-request processor, and synchronous memory transport now exercise
  generated service models under Binary and Compact; typed generated facades,
  application exceptions, oneway, framing, and TCP remain ahead.
- 2026-09-24: Issue #18 adds generated typed clients, handler callbacks, and
  method dispatch for request/reply services. The generated code is compiled
  and exercised against both wire protocols; inheritance is deferred.
- 2026-09-24: Issue #20 adds standard application-exception payloads, unknown
  method and handler-failure envelopes, and no-response `ONEWAY` dispatch.
  Generated mixed-service facades and Apache Python wire fixtures run on all
  four backends. Inherited-service facades remain deferred.
- 2026-09-24: Issue #22 adds a bounded big-endian framed codec and incremental
  stream decoder. Binary/Compact frame bytes are checked against Apache Python
  `TFramedTransport`; a framed in-memory RPC example stays portable. Socket
  I/O is the next separate increment.
- 2026-09-24: Issue #24 adds a native-only, loopback TCP tutorial. It uses
  the portable framed decoder and generated service models with the official
  async socket runtime. Binary and Compact are exercised with fragmented
  writes and two sequential calls; the core RPC package stays portable.
- 2026-09-25: Issue #26 starts the 0.3.0 release. Version metadata,
  documentation, the registry publication, tag, and GitHub Release are
  tracked separately so the published artifact can be verified before
  marking Phase 5 complete.
- 2026-09-25: PR #27 passed both CI jobs and was merged. Main CI
  https://github.com/pxgt/moonthrift/actions/runs/36088294413 passed all
  stable backends, examples, package, and Apache Python interoperability.
  Xpeng/moonthrift 0.3.0 was published on Mooncakes with a successful build;
  a fresh consumer project installed it and called its public API. Annotated
  tag v0.3.0 and the GitHub Release point to the publication source commit.
  Phase 5 is complete; Phase 6 is next.
