namespace mbt demo.multifile.types

typedef i64 UserId

struct User {
  1: required UserId id
  2: optional string display_name
}

service BaseDirectory {
  void ping()
}
