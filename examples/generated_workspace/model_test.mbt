///|
test "workspace-generated declarations are usable" {
  let user : @generated_workspace.ExamplesMultifileCommonTypesUser = {
    id: 7L,
    display_name: Some("MoonBit"),
  }
  let request : @generated_workspace.GetUserRequest = { id: user.id, }
  assert_eq(request.id, 7L)
  assert_eq(
    @generated_workspace.ExamplesMultifileCommonTypesUser::decode_binary(
      user.encode_binary(),
    ),
    user,
  )
  assert_eq(
    @generated_workspace.GetUserRequest::decode_compact(
      request.encode_compact(),
    ),
    request,
  )
}
