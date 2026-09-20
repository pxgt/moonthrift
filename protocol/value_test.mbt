///|
test "typed value helpers validate wire kinds and UTF-8" {
  assert_eq(@protocol.string_value("月兔").require_string(), "月兔")
  let integer : @protocol.Value = I64Value(42L)
  assert_eq(integer.require_i64(), 42L)
  let wrong_type : @protocol.Value = I32Value(1)
  try wrong_type.require_string() catch {
    TypeMismatch(expected~, actual~) => {
      assert_eq(expected, Binary)
      assert_eq(actual, I32)
    }
    _ => fail("expected a type mismatch")
  } noraise {
    _ => fail("expected a type mismatch")
  }
  let malformed : @protocol.Value = BinaryValue([0xff])
  try malformed.require_string() catch {
    InvalidValue(message) =>
      assert_eq(message, "binary field is not valid UTF-8")
    _ => fail("expected invalid UTF-8")
  } noraise {
    _ => fail("expected invalid UTF-8")
  }
}

///|
test "typed container helpers accept empty compact containers" {
  assert_eq(
    @protocol.MapValue(key_type=Stop, value_type=Stop, entries=[]).require_map(
      Binary,
      I64,
    ),
    [],
  )
  assert_eq(
    @protocol.ListValue(element_type=I32, values=[]).require_list(I64),
    [],
  )
}
