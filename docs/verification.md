# Verification

The `0.2.0` release is developed with the 2026-09-15 stable MoonBit toolchain:

```text
moon 0.1.20260915 (2e1a46d 2026-09-15)
moonc v0.10.13+cbb11c36f (2026-09-15)
moonrun 0.1.20260915 (2e1a46d 2026-09-15)
```

Run the complete local gate from the repository root:

```sh
moon update
moon fmt --check
moon info --target all
git diff --exit-code
moon check --target all --deny-warn --warn-list +73
moon build --target all
moon test --target all --deny-warn --warn-list +73
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
```

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

The tests cover lexer locations and failures, every principal IDL declaration,
semantic diagnostics, schema evolution, known binary/compact byte fixtures,
nested containers, defensive limits, malformed protocol data, RPC envelopes,
code generation, and use of generated declarations. All portable packages run
on wasm, wasm-gc, JavaScript, and native; only the filesystem CLI is native.
