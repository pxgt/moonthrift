namespace mbt tutorial

typedef i64 UserId

enum Role {
  USER = 1,
  ADMIN = 2,
  AUDITOR = 3
}

struct User {
  1: required UserId id,
  2: required string name,
  3: optional Role role,
  4: optional string email
}

exception UserNotFound {
  1: required UserId id,
  2: string message
}

service UserDirectory {
  User get_user(1: UserId id) throws (1: UserNotFound missing),
  list<User> list_users(),
  void health()
}
