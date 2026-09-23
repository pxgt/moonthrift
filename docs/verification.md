# Verification

The `0.2.0` release is verified with the 2026-09-20 stable MoonBit toolchain:

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
moon run cmd/main --target native
moon run cmd/main --target native -- check examples/tutorial.thrift
moon run cmd/main --target native -- inspect examples/tutorial.thrift
moon run cmd/main --target native -- diff examples/tutorial.thrift examples/tutorial-v2.thrift
moon run cmd/main --target native -- generate examples/tutorial.thrift /tmp/tutorial.generated.mbtx
moon run cmd/main --target native -- generate examples/multifile/api.thrift /tmp/multifile.generated.mbtx
moon fmt /tmp/tutorial.generated.mbtx /tmp/multifile.generated.mbtx
moon package --frozen
python -m pip install -r interop/python/requirements.txt
python interop/python/reference.py --check
python tools/test_compat_cli.py
```

Warning 079 is temporarily kept non-fatal with `-79` while the explicit
derived-trait method export migration is tracked in
[Issue #13](https://github.com/pxgt/moonthrift/issues/13). All other enabled
warnings remain errors. The migration changes API declaration mechanics, not
Binary/Compact wire behavior.

Compare the two formatted generated files with
`examples/generated/model.mbt` and `examples/generated_workspace/model.mbt`.
Both generated packages are part of the regular check/test graph. Their tests
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

The tests cover lexer locations and failures, every principal IDL declaration,
semantic diagnostics, schema evolution, known binary/compact byte fixtures,
nested containers, defensive limits, malformed protocol data, RPC envelopes,
code generation, and use of generated declarations. All portable packages run
on wasm, wasm-gc, JavaScript, and native; only the filesystem CLI is native.
