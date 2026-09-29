///|
#warnings("-unnecessary_annotation")
fn sample_inventory() -> @generated_containers.Inventory {
  {
    history: [ACTIVE, SUSPENDED, ACTIVE],
    allowed: Some([ACTIVE, DELETED]),
    counts: Some(Map::from_array([(ACTIVE, 2), (SUSPENDED, 1)])),
    by_owner: Some(Map::from_array([("ada", [ACTIVE]), ("lin", [])])),
    badges: Some(
      Map::from_array([(ACTIVE, { label: "gold", level: Some(3), })]),
    ),
    marker: Some(@generated_containers.Marker::{ }),
    id: Some(
      b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff",
    ),
    related: Some([
      b"\xff\xee\xdd\xcc\xbb\xaa\x99\x88\x77\x66\x55\x44\x33\x22\x11\x00", b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff",
    ]),
  }
}

///|
test "enum containers and empty records round-trip through Binary and Compact" {
  let inventory = sample_inventory()
  assert_eq(
    @generated_containers.Inventory::decode_binary(inventory.encode_binary()),
    inventory,
  )
  assert_eq(
    @generated_containers.Inventory::decode_compact(inventory.encode_compact()),
    inventory,
  )
}

///|
test "enum values are usable as map keys" {
  let counts : Map[@generated_containers.Status, Int] = Map::from_array([
    (ACTIVE, 1),
  ])
  counts[DELETED] = 4
  assert_eq(counts.get(DELETED), Some(4))
  assert_eq(counts.length(), 2)
}

///|
test "unknown enum values inside a list are rejected" {
  let value : @protocol.Value = StructValue([
    { id: 1, value: ListValue(element_type=I32, values=[I32Value(99)]), },
  ])
  try @generated_containers.Inventory::from_thrift_value(value) catch {
    InvalidEnum(type_name="Status", value=99) => ()
    _ => fail("unexpected error for an unknown enum value")
  } noraise {
    _ => fail("expected an unknown enum value to be rejected")
  }
}
