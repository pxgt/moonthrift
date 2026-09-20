namespace mbt tutorial

/** Stable identifier used by the directory service. */
typedef i64 UserId

/// Access role assigned to a user.
enum Role {
  /// Standard directory member.
  USER = 1,
  /// Directory administrator.
  ADMIN = 2
}

/// A user record transported by the tutorial service.
struct User {
  /// Stable user identifier.
  1: required UserId id,
  /// Display name encoded as UTF-8.
  2: required string name,
  3: optional Role role,
  4: optional list<string> aliases,
  5: optional map<string, i32> scores,
  6: optional set<i64> flags,
  7: i32 revision = 1
}

union UserLookup {
  1: UserId id,
  2: string name
}

exception UserNotFound {
  1: required UserId id,
  2: string message
}

/// Typed directory operations.
service UserDirectory {
  /// Fetch one user or return a declared missing-user exception.
  User get_user(1: UserId id) throws (1: UserNotFound missing),
  list<User> list_users()
}
