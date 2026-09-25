///|
// Keep the value shape stable: a mix of primitive, binary, and container fields.
fn protocol_benchmark_fixture(fields : Int) -> @protocol.Value {
  let values : Array[@protocol.FieldValue] = []
  for index in 0..<fields {
    let value : @protocol.Value = match index % 4 {
      0 => I64Value(index.to_int64() * 104729L)
      1 => BinaryValue(b"MoonThrift benchmark")
      2 => BoolValue(index % 8 == 2)
      _ =>
        ListValue(element_type=I32, values=[
          I32Value(index),
          I32Value(index + 1),
          I32Value(index + 2),
        ])
    }
    values.push({ id: index + 1, value, })
  }
  StructValue(values)
}

///|
test (b : @bench.T) {
  let small = protocol_benchmark_fixture(16)
  let large = protocol_benchmark_fixture(256)
  let small_binary = @protocol.encode_binary(small)
  let large_binary = @protocol.encode_binary(large)
  let small_compact = @protocol.encode_compact(small)
  let large_compact = @protocol.encode_compact(large)
  assert_eq(@protocol.decode_binary(small_binary, Struct), small)
  assert_eq(@protocol.decode_binary(large_binary, Struct), large)
  assert_eq(@protocol.decode_compact(small_compact, Struct), small)
  assert_eq(@protocol.decode_compact(large_compact, Struct), large)

  b.bench(name="binary_encode_16_fields", fn() {
    b.keep(
      @protocol.encode_binary(small) catch {
        _ => abort("binary encode benchmark failed")
      },
    )
  })
  b.bench(name="binary_decode_16_fields", fn() {
    b.keep(
      @protocol.decode_binary(small_binary, Struct) catch {
        _ => abort("binary decode benchmark failed")
      },
    )
  })
  b.bench(name="compact_encode_16_fields", fn() {
    b.keep(
      @protocol.encode_compact(small) catch {
        _ => abort("compact encode benchmark failed")
      },
    )
  })
  b.bench(name="compact_decode_16_fields", fn() {
    b.keep(
      @protocol.decode_compact(small_compact, Struct) catch {
        _ => abort("compact decode benchmark failed")
      },
    )
  })
  b.bench(name="binary_encode_256_fields", fn() {
    b.keep(
      @protocol.encode_binary(large) catch {
        _ => abort("binary encode benchmark failed")
      },
    )
  })
  b.bench(name="binary_decode_256_fields", fn() {
    b.keep(
      @protocol.decode_binary(large_binary, Struct) catch {
        _ => abort("binary decode benchmark failed")
      },
    )
  })
  b.bench(name="compact_encode_256_fields", fn() {
    b.keep(
      @protocol.encode_compact(large) catch {
        _ => abort("compact encode benchmark failed")
      },
    )
  })
  b.bench(name="compact_decode_256_fields", fn() {
    b.keep(
      @protocol.decode_compact(large_compact, Struct) catch {
        _ => abort("compact decode benchmark failed")
      },
    )
  })
}
