// Enum values inside every container shape, enum map keys, and an empty record.

namespace mbt demo.containers

/// Lifecycle state of an account.
enum Status {
  ACTIVE = 1,
  SUSPENDED = 2,
  DELETED = 3
}

/// A small record used as a map value.
struct Badge {
  1: required string label
  2: optional i32 level
}

/// An empty record, common as a request or response placeholder.
struct Marker {}

/// Exercises enums in lists, sets, map keys, map values, and nested containers.
struct Inventory {
  1: required list<Status> history
  2: optional set<Status> allowed
  3: optional map<Status, i32> counts
  4: optional map<string, list<Status>> by_owner
  5: optional map<Status, Badge> badges
  6: optional Marker marker
}
