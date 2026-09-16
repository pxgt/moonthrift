///|
test "generated declarations are usable" {
  let user : @generated.User = { id: 7L, name: "Ada", role: Some(ADMIN), }
  assert_eq(user.id, 7L)
  assert_eq(@generated.Role::from_thrift_i32(2), Some(ADMIN))
  let role : @generated.Role = ADMIN
  assert_eq(role.to_thrift_i32(), 2)
}
