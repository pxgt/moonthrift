# Parser and protocol benchmarks

These are reproducible microbenchmarks for Phase 6, not throughput promises for
a complete RPC service. The benchmark sources are
[`parser_bench_test.mbt`](../parser_bench_test.mbt) and
[`protocol/wire_bench_test.mbt`](../protocol/wire_bench_test.mbt). They are kept
with the code so later changes can be measured against the same workloads.

## Workloads

- Parser: an in-memory IDL document with one `typedef` and either 8 or 128
  uniquely named records. Each record has required, optional, list, and map
  fields. Only `parse_idl` is timed; document construction is outside the
  measured callback.
- Protocol: a dynamic `StructValue` with 16 or 256 fields, cycling through
  64-bit integers, fixed binary data, booleans, and three-element integer
  lists. The Binary and Compact encoders receive the same value. Decoder
  input is encoded before timing. Each result is retained with `@bench.T.keep`
  so the compiler cannot discard the operation.
- Before timing, the parser checks the expected declaration counts and each
  protocol variant checks its round trip. An unexpected codec error aborts the
  run instead of being silently ignored.

Run from the repository root:

```sh
moon bench parser_bench_test.mbt --target wasm-gc --release --warn-list +73-79
moon bench protocol/wire_bench_test.mbt --target wasm-gc --release --warn-list +73-79
```

`moon bench` performs calibration and reports ten samples per case. Run on an
otherwise idle machine, repeat before making a performance claim, and compare
only measurements from the same toolchain, backend, and hardware. The
`-79` warning exception is documented in [verification.md](verification.md).

## Baseline (2026-09-25)

Measured on Windows, Intel Core i7-14700HX, with MoonBit
`moon 0.1.20260920` / `moonc v0.10.14+7d59c7ec9`, wasm-gc release build.
Times are per operation as reported by `moon bench` (mean ± standard
deviation across ten samples). Machine load, compilation mode, and runtime
can change these numbers; they are a starting point for regression analysis.

| Operation | Mean ± σ |
| --- | ---: |
| Parse 8 records | 23.63 µs ± 0.36 µs |
| Parse 128 records | 384.37 µs ± 5.87 µs |
| Binary encode, 16 fields | 346.44 ns ± 14.85 ns |
| Binary decode, 16 fields | 592.13 ns ± 22.83 ns |
| Compact encode, 16 fields | 322.34 ns ± 15.11 ns |
| Compact decode, 16 fields | 516.46 ns ± 11.59 ns |
| Binary encode, 256 fields | 3.98 µs ± 0.12 µs |
| Binary decode, 256 fields | 10.70 µs ± 0.30 µs |
| Compact encode, 256 fields | 4.45 µs ± 0.06 µs |
| Compact decode, 256 fields | 9.61 µs ± 0.43 µs |

The fixtures exercise specific shapes and are not representative of every IDL
or Thrift value. In particular, the protocol cases contain no deeply nested
structures or large binary payloads; the existing defensive-limit and fuzz
tests cover correctness under different shapes, not their performance.
