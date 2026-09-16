# Verification

The `0.1.0` release is developed with the 2026-09-15 stable MoonBit toolchain:

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
moon run cmd/main --target native -- generate examples/tutorial.thrift _build/tutorial.generated.mbt
moon package --frozen
```

Normalize line endings and compare `_build/tutorial.generated.mbt` with
`examples/generated/model.mbt`. The generated package is also part of the
regular check/test graph, so invalid emitted syntax fails CI.

The tests cover lexer locations and failures, every principal IDL declaration,
semantic diagnostics, schema evolution, known binary/compact byte fixtures,
nested containers, defensive limits, malformed protocol data, RPC envelopes,
code generation, and use of generated declarations. All portable packages run
on wasm, wasm-gc, JavaScript, and native; only the filesystem CLI is native.
