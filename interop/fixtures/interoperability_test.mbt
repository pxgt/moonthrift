///|
fn reference_user() -> @generated.User {
  {
    id: -9223372036854775807L - 1L,
    name: "月兔 🌙",
    role: Some(ADMIN),
    aliases: Some(["", "MoonBit"]),
    scores: Some({ "minimum": -2147483648 }),
    flags: Some([-9223372036854775807L - 1L, 9223372036854775807L]),
    revision: 2147483647,
  }
}

///|
test "Apache Thrift Python Binary user is bidirectionally compatible" {
  let expected = reference_user()
  assert_eq(@generated.User::decode_binary(python_binary_user), expected)
  assert_eq(expected.encode_binary(), python_binary_user)
}

///|
test "Apache Thrift Python Compact user is bidirectionally compatible" {
  let expected = reference_user()
  assert_eq(@generated.User::decode_compact(python_compact_user), expected)
  assert_eq(expected.encode_compact(), python_compact_user)
}

///|
test "generated decoders ignore Python fields added by a future schema" {
  let expected = reference_user()
  assert_eq(
    @generated.User::decode_binary(python_binary_user_unknown),
    expected,
  )
  assert_eq(
    @generated.User::decode_compact(python_compact_user_unknown),
    expected,
  )
}

///|
test "Apache Thrift Python exceptions are bidirectionally compatible" {
  let expected : @generated.UserNotFound = {
    id: 9223372036854775807L,
    message: "没有找到用户",
  }
  assert_eq(
    @generated.UserNotFound::decode_binary(python_binary_exception),
    expected,
  )
  assert_eq(expected.encode_binary(), python_binary_exception)
  assert_eq(
    @generated.UserNotFound::decode_compact(python_compact_exception),
    expected,
  )
  assert_eq(expected.encode_compact(), python_compact_exception)
}

///|
test "Apache Thrift Python empty containers preserve valid wire data" {
  let binary = @protocol.decode_binary(python_binary_empty_containers, Struct)
  let compact = @protocol.decode_compact(
    python_compact_empty_containers,
    Struct,
  )
  assert_eq(@protocol.encode_binary(binary), python_binary_empty_containers)
  assert_eq(@protocol.encode_compact(compact), python_compact_empty_containers)
}

///|
test "Python unknown nested containers decode with integer boundaries" {
  let binary = @protocol.decode_binary(python_binary_user_unknown, Struct)
  let compact = @protocol.decode_compact(python_compact_user_unknown, Struct)
  for value in [binary, compact] {
    let fields = value.require_struct()
    let future_index = fields.search_by(field => field.id == 99).unwrap()
    let future = fields[future_index].value.require_map(Binary, List)
    assert_eq(future.length(), 1)
    let (key, limits) = future[0]
    assert_eq(key.require_string(), "limits")
    assert_eq(limits.require_list(I64).map(value => value.require_i64()), [
      -9223372036854775807L - 1L,
      9223372036854775807L,
    ])
  }
}
