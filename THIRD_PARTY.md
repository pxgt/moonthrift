# Third-party and specification notice

MoonThrift is an original MoonBit implementation informed by the public Apache
Thrift specification and interoperability behavior:

- Project: Apache Thrift
- Source: https://github.com/apache/thrift
- Documentation: https://thrift.apache.org/docs/idl
- Reference runtime: Apache Thrift Python 0.24.0
- Runtime source: https://pypi.org/project/thrift/0.24.0/
- License: Apache License 2.0

No source file from Apache Thrift is copied into this repository. Protocol
constants and required wire behavior are compatibility facts.

The files in `interop/fixtures/python_fixtures.mbt` are deterministic wire
bytes generated from MoonThrift's original tutorial schema by
`interop/python/reference.py` using the unmodified Apache Thrift Python 0.24.0
runtime. They contain serialized test data, not Apache Thrift source code. The
generator, its inputs, and its validation logic are all retained so the
fixtures can be independently rebuilt and audited.
