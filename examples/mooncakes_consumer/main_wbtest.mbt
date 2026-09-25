///|
test "published Mooncakes package works in a separate module" {
  assert_eq(
    verify_published_package(),
    "Mooncakes 0.3.0: parsed 1 definition; Binary and Compact round trips passed",
  )
}
