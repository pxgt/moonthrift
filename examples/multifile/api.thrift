include "common/types.thrift"

namespace mbt demo.multifile

struct GetUserRequest {
  1: required types.UserId id
}

service UserDirectory extends types.BaseDirectory {
  types.User get_user(1: GetUserRequest request)
}
