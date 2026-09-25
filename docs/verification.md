# Verification

The `0.3.0` release is verified with the
2026-09-20 stable MoonBit toolchain:

```text
moon 0.1.20260920 (914d7da 2026-09-20)
moonc v0.10.14+7d59c7ec9 (2026-09-18)
moonrun 0.1.20260920 (914d7da 2026-09-20)
```

Run the complete local gate from the repository root:

```sh
moon update
moon fmt --check
moon info --target all
git diff --exit-code
moon check --target all --deny-warn --warn-list +73-79
moon build --target all
moon test --target all --deny-warn --warn-list +73-79
moon bench --build-only --target all --release --deny-warn --warn-list +73-79
moon run cmd/main --target native
moon run cmd/main --target native -- check examples/tutorial.thrift
moon run cmd/main --target native -- inspect examples/tutorial.thrift
moon run cmd/main --target native -- diff examples/tutorial.thrift examples/tutorial-v2.thrift
moon run cmd/main --target native -- generate examples/tutorial.thrift /tmp/tutorial.generated.mbtx
moon run cmd/main --target native -- generate examples/multifile/api.thrift /tmp/multifile.generated.mbtx
moon run cmd/main --target native -- generate examples/oneway.thrift /tmp/oneway.generated.mbtx
moon fmt /tmp/tutorial.generated.mbtx /tmp/multifile.generated.mbtx /tmp/oneway.generated.mbtx
moon package --frozen
python -m pip install -r interop/python/requirements.txt
python interop/python/reference.py --check
python tools/test_compat_cli.py
moon run examples/rpc_demo --target native
moon run examples/directory_demo --target wasm-gc
moon test examples/directory_demo --target all --deny-warn --warn-list +73-79
moon -C examples/mooncakes_consumer check --target all --deny-warn --warn-list +73-79
moon -C examples/mooncakes_consumer test --target all --deny-warn --warn-list +73-79
moon -C examples/mooncakes_consumer run . --target wasm-gc
moon test examples/tcp_demo --target native --deny-warn --warn-list +73-79
moon run examples/tcp_demo --target native
```

Warning 079 is temporarily kept non-fatal with `-79` while the explicit
derived-trait method export migration is tracked in
[Issue #13](https://github.com/pxgt/moonthrift/issues/13). All other enabled
warnings remain errors. The migration changes API declaration mechanics, not
Binary/Compact wire behavior.

Compare the three formatted generated files with
`examples/generated/model.mbt`, `examples/generated_workspace/model.mbt`,
and `examples/generated_oneway/model.mbt`. All generated packages are part of
the regular check/test graph. Their tests
execute Binary and Compact round trips on all stable backends, including
nested containers, cross-file types, service results, defaults, unknown fields,
and missing-required-field errors.

The independent Python interoperability gate pins Apache Thrift Python 0.24.0,
rebuilds and decodes all checked-in fixtures, and runs the focused MoonBit
fixture package on all four stable backends. See `docs/interoperability.md` for
the complete matrix and provenance model.

The compatibility smoke test checks breaking and passing directions, exact
rule suppression, stable JSON, Markdown report files, GitHub annotations, and
comparison against an external Git repository's committed schema baseline.
PR CI also compares `examples/` with the PR base commit. See
`docs/compatibility-ci.md` for the reusable workflow and behavior contract.

The RPC tests run on all stable backends. They cover Binary and Compact
in-memory exchanges, generated service success and declared-exception models,
CALL/ONEWAY kind validation, method and sequence-ID matching, application
exception type codes, unknown-method envelopes, bounded frame lengths,
fragmented/coalesced frame decoding, and a native demo that prints
`get_user(7) -> Ada` and `framed get_user(7) -> Ada`. Apache Python fixtures
independently cover RPC envelopes and framed bytes. See `docs/rpc-runtime.md`
for the current boundary and deferred features.

The separate TCP tutorial uses an ephemeral loopback listener and runs both
wire protocols with two sequential calls each. CI runs it on Ubuntu. The
official async dependency currently requires MSVC for Windows native builds;
the MinGW compiler alone cannot build its C runtime. Windows contributors can
use an MSVC environment or run the native check in Linux/WSL.

The [multi-file service tutorial](multifile-service-tutorial.md) links a
shared IDL type into a generated service model and exercises Binary/Compact
clients, handlers, framing, and application-error behavior. Its separate
consumer module resolves the published Mooncakes 0.3.0 package instead of
the checkout's source; CI checks both paths.

The release-mode parser and Binary/Compact benchmarks are compiled in the
verification gate above. To run the calibrated measurements and compare them
with the recorded machine-specific baseline, see
[benchmarks.md](benchmarks.md). Benchmarks are not a pass/fail performance gate.

The tests cover lexer locations and failures, every principal IDL declaration,
semantic diagnostics, schema evolution, known binary/compact byte fixtures,
nested containers, defensive limits, malformed protocol data, RPC envelopes,
code generation, and use of generated declarations. All portable packages run
on wasm, wasm-gc, JavaScript, and native; the filesystem CLI and TCP tutorial
are native-only.

## Core coverage

Run `python tools/check_core_coverage.py --minimum 85` from the repository
root. The script runs fresh instrumented MoonBit tests, then reads the
`moon coverage report -f summary -p <package>` totals for the root IDL,
`protocol`, `codegen`, and `rpc` packages. It combines covered and measurable
lines before comparing with the 85% floor; it does not average package
percentages. Generated examples, demos, CLI adapters, and interoperability
fixtures are outside this **core-package** denominator but remain in the
regular four-backend test gate.

On the 2026-09-20 stable toolchain, the initial Phase 6 baseline was
1859/2366 (78.57%). Focused protocol and generator tests raised it to
2059/2366 (87.02%). The CI gate runs this check after the normal four-backend
tests, so a later drop below 85% fails the PR.

## Deterministic fuzz and property corpus

`protocol/fuzz_test.mbt` uses fixed seeds `0x4d544852` and
`0x46555a5a`. It generates 512 bounded nested values and checks Binary
and Compact round trips and stable encoding. It also truncates a valid RPC
envelope at every byte boundary and feeds 1024 arbitrary byte strings (up to
64 bytes) to both decoders with depth 4, container size 8, and binary size 32
limits. A byte string may be valid; if so, its decoded value must re-encode to
a stable canonical representation. Both accepted and rejected paths are
required. The Compact wire format omits key/value type IDs for an empty map,
so generated empty maps use `Stop/Stop` for equality after decoding.

`idl_fuzz_test.mbt` uses fixed seed `0x49444c46` to delete, replace,
or insert a character in 768 valid IDL templates. Each mutation must produce
a schema or a typed `IdlError`; successful parses must be deterministic
and safe to pass through semantic checking. Both outcomes are required.
These tests are reproducible regression corpora, not a claim of exhaustive
coverage or a replacement for a coverage-guided fuzzer. With these corpora,
the same core-package coverage check reports 2102/2366 lines (88.84%).

Run the focused corpora with:

```sh
moon test protocol/fuzz_test.mbt --target all --deny-warn --warn-list +73-79
moon test idl_fuzz_test.mbt --target all --deny-warn --warn-list +73-79
```
