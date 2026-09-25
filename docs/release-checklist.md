# 0.3.0 release checklist

- [x] Portable RPC processor, typed service facades, application exceptions,
  ONEWAY, and bounded framed transport covered on all four stable backends
- [x] Native-only TCP loopback tutorial tested with Binary and Compact
- [x] Apache Thrift Python wire interoperability and main CI green
- [x] Release-preparation PR merged and release commit CI green
- [x] Mooncakes 0.3.0 published under Xpeng with successful build
- [x] Fresh consumer installed 0.3.0 and called a public API
- [x] Annotated v0.3.0 tag and GitHub Release created

Release evidence: [PR #27](https://github.com/pxgt/moonthrift/pull/27),
[main CI](https://github.com/pxgt/moonthrift/actions/runs/36088294413),
[Mooncakes 0.3.0](https://mooncakes.io/docs/Xpeng/moonthrift@0.3.0),
and [GitHub Release](https://github.com/pxgt/moonthrift/releases/tag/v0.3.0).

## 0.2.0 release record

- [x] Apache Thrift Python 0.24.0 reference runtime pinned
- [x] Binary and Compact fixtures reproducibly generated and Python-decoded
- [x] Bidirectional typed codec compatibility on all four stable backends
- [x] Integer boundaries, Unicode, empty/nested containers, exceptions, and
  unknown fields covered
- [x] Fixture provenance and Apache-2.0 license source documented
- [x] Independent interoperability CI job configured
- [x] Pull request and both CI jobs green
- [x] Mooncakes 0.2.0 build successful
- [x] Annotated `v0.2.0` tag and GitHub release created

## 0.1.0 release record

- [x] Public repository and traceable commit history
- [x] Complete README, runnable examples, license, contribution, and security docs
- [x] Source-aware IDL parser and semantic checks
- [x] Binary and compact values plus RPC messages
- [x] Compiled MoonBit generator output
- [x] Compatibility analyzer and CLI workflows
- [x] Four-backend format/check/build/test gate
- [x] Reproducible package artifact
- [x] Public GitHub CI green
- [x] Mooncakes build successful
- [x] Annotated tag and GitHub release created

The unchecked release steps are completed only after their corresponding
public service reports success. Issue #1 tracks the online evidence; issue #2
remains open for post-release maintenance.
