# Apache Thrift interoperability

MoonThrift checks wire compatibility against Apache Thrift Python rather than
relying only on MoonBit-to-MoonBit round trips. The reference version for the
`0.2.0` milestone is `thrift==0.24.0`.

## What is verified

The fixture schema follows `examples/tutorial.thrift`. For both Binary and
Compact protocols, the matrix covers:

- Python encode to MoonBit typed decode;
- MoonBit typed encode to the exact bytes accepted by Python;
- signed 32-bit and 64-bit boundary values;
- UTF-8 strings and empty strings;
- list, set, map, empty-container, and nested-container encodings;
- a generated exception record;
- a future unknown field containing a nested container.
- standard `TApplicationException` RPC envelopes and `ONEWAY` requests.
- Apache Python `TFramedTransport` output for Binary/Compact application
  exceptions and `ONEWAY` calls, checked against the MoonBit frame codec.

`interop/python/reference.py` writes each value with the public Apache Thrift
protocol API and immediately reads it back with an independent Python decoder.
The resulting bytes are checked into `interop/fixtures/python_fixtures.mbt`.
MoonBit tests decode those bytes and require MoonBit encoding to match them
byte-for-byte. Together these checks establish both directions without making
the portable MoonBit test packages depend on Python or a filesystem.

## Reproduce locally

Use an isolated Python environment and install the exact reference version:

```sh
python -m venv .venv
.venv/bin/python -m pip install -r interop/python/requirements.txt
.venv/bin/python interop/python/reference.py --check
moon test interop/fixtures --target all --deny-warn --warn-list +73-79
```

On Windows PowerShell, replace `.venv/bin/python` with
`.venv/Scripts/python.exe`.

To intentionally refresh fixtures after reviewing a reference-runtime or
schema change, run:

```sh
python interop/python/reference.py --write
moon fmt
python interop/python/reference.py --check
```

The independent `interoperability-python` CI job repeats fixture regeneration,
Python decoding, and the four-backend MoonBit test matrix on every pull request
and every push to `main`.

## Version and license policy

The Python runtime is exactly pinned. Updating it requires a reviewed fixture
diff, a successful full matrix, and an update to `THIRD_PARTY.md`. MoonThrift
does not vendor Apache Thrift source; fixture provenance and license details are
recorded in `THIRD_PARTY.md`.
