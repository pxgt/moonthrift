///|
test "generated declarations are usable" {
  let user : @generated.User = {
    id: 7L,
    name: "Ada",
    role: Some(ADMIN),
    aliases: Some(["A", "月兔"]),
    scores: Some({ "compiler": 10, "runtime": 9 }),
    flags: Some([2L, 3L]),
    revision: 1,
  }
  assert_eq(user.id, 7L)
  assert_eq(@generated.Role::from_thrift_i32(2), Some(ADMIN))
  let role : @generated.Role = ADMIN
  assert_eq(role.to_thrift_i32(), 2)
  assert_eq(@generated.User::decode_binary(user.encode_binary()), user)
  assert_eq(@generated.User::decode_compact(user.encode_compact()), user)
}

///|
test "generated record decoding skips unknown fields and applies defaults" {
  let value : @protocol.Value = StructValue([
    { id: 1, value: I64Value(8L), },
    { id: 2, value: @protocol.string_value("Grace"), },
    { id: 99, value: BoolValue(true), },
  ])
  let user = @generated.User::from_thrift_value(value)
  assert_eq(user.id, 8L)
  assert_eq(user.name, "Grace")
  assert_eq(user.role, None)
  assert_eq(user.aliases, None)
  assert_eq(user.revision, 1)
}

///|
test "generated record decoding rejects a missing required field" {
  let value : @protocol.Value = StructValue([{ id: 1, value: I64Value(9L), }])
  try @generated.User::from_thrift_value(value) catch {
    MissingRequiredField(type_name~, field_id~, field_name~) => {
      assert_eq(type_name, "User")
      assert_eq(field_id, 2)
      assert_eq(field_name, "name")
    }
    _ => fail("expected a missing required field error")
  } noraise {
    _ => fail("expected a missing required field error")
  }
}

///|
test "generated enums unions and service results round trip" {
  let admin : @generated.Role = ADMIN
  assert_eq(@generated.Role::decode_compact(admin.encode_compact()), admin)
  let lookup : @generated.UserLookup = Name("Ada")
  assert_eq(
    @generated.UserLookup::decode_binary(lookup.encode_binary()),
    lookup,
  )
  let user : @generated.User = {
    id: 7L,
    name: "Ada",
    role: Some(ADMIN),
    aliases: None,
    scores: None,
    flags: None,
    revision: 2,
  }
  let success : @generated.UserDirectoryGetUserResult = Success(user)
  assert_eq(
    @generated.UserDirectoryGetUserResult::decode_compact(
      success.encode_compact(),
    ),
    success,
  )
  let missing : @generated.UserDirectoryGetUserResult = Missing({
    id: 99L,
    message: "not found",
  })
  assert_eq(
    @generated.UserDirectoryGetUserResult::decode_binary(
      missing.encode_binary(),
    ),
    missing,
  )
  let empty : @generated.UserDirectoryListUsersResult = Success([])
  assert_eq(
    @generated.UserDirectoryListUsersResult::decode_binary(
      empty.encode_binary(),
    ),
    empty,
  )
}
