///|
// Construct the input before timing so this measures lexing and parsing,
// not fixture generation or filesystem I/O.
fn parser_benchmark_fixture(records : Int) -> String {
  let source = StringBuilder()
  source.write_string("namespace mbt bench\ntypedef i64 Key\n")
  for index in 0..<records {
    source.write_string(
      "struct Record\{index} { 1: required Key id, 2: optional string name, 3: optional list<i32> values, 4: optional map<string, i64> counters }\n",
    )
  }
  source.to_string()
}

///|
test (b : @bench.T) {
  let small = parser_benchmark_fixture(8)
  let large = parser_benchmark_fixture(128)
  assert_eq(@moonthrift.parse_idl(small).definitions.length(), 9)
  assert_eq(@moonthrift.parse_idl(large).definitions.length(), 129)
  b.bench(name="parse_8_records", fn() {
    b.keep(
      @moonthrift.parse_idl(small) catch {
        _ => abort("parser benchmark failed")
      },
    )
  })
  b.bench(name="parse_128_records", fn() {
    b.keep(
      @moonthrift.parse_idl(large) catch {
        _ => abort("parser benchmark failed")
      },
    )
  })
}
