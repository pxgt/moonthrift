include "common/types.thrift"

namespace mbt demo.multifile.directory

service Directory {
  types.User get_user(1: types.UserId id)
}
