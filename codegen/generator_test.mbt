///|
test "generator emits records enums unions constants and service models" {
  let idl =
    #|/// Stable identifier.
    #|typedef i64 UserId
    #|/// Access role.
    #|enum Role { USER = 1, ADMIN = 4 }
    #|/// User record.
    #|struct User { 1: required UserId id, 2: optional string display_name }
    #|union Lookup { 1: UserId id, 2: string email }
    #|/// Default server port.
    #|const i32 default_port = 9090
    #|exception Missing { 1: string message }
    #|service Users { User get(1: UserId id) throws (1: Missing missing) }
    #|
  let schema = @moonthrift.parse_idl(idl, source="users.thrift")
  let generated = @codegen.generate_moonbit(schema, path="users.mbt")
  assert_eq(generated.path, "users.mbt")
  assert_true(generated.content.contains("pub type UserId = Int64"))
  assert_true(generated.content.contains("pub(all) enum Role"))
  assert_true(generated.content.contains("display_name : String?"))
  assert_true(generated.content.contains("pub(all) enum Lookup"))
  assert_true(generated.content.contains("pub let default_port : Int = 9090"))
  assert_true(generated.content.contains("pub(all) struct UsersGetArgs"))
  assert_true(generated.content.contains("pub(all) enum UsersGetResult"))
  assert_true(generated.content.contains("User::to_thrift_value"))
  assert_true(generated.content.contains("User::decode_compact"))
  assert_true(generated.content.contains("Lookup::from_thrift_value"))
  assert_true(generated.content.contains("UsersGetResult::encode_binary"))
  assert_true(generated.content.contains("pub struct UsersClient"))
  assert_true(generated.content.contains("pub(all) struct UsersHandler"))
  assert_true(generated.content.contains("UsersClient::get"))
  assert_true(generated.content.contains("UsersHandler::serve_once"))
  assert_true(generated.content.contains("/// Stable identifier."))
  assert_true(generated.content.contains("/// Access role."))
  assert_true(generated.content.contains("/// User record."))
  assert_true(generated.content.contains("/// Default server port."))
}

///|
test "type renderer handles nested containers and qualified names" {
  let ty : @moonthrift.TypeRef = Map(Base(String), List(Named("common.User")))
  assert_eq(@codegen.render_type(ty), "Map[String, Array[User]]")
  assert_eq(
    @codegen.render_type(CppType(List(Base(Uuid)), "std::vector")),
    "Array[Bytes]",
  )
}

///|
test "workspace generator prefixes included declarations and rewrites references" {
  let sources : Map[String, String] = {
    "api.thrift": (
      #|include "common/types.thrift"
      #|struct Request { 1: required types.User user }
      #|service Api { types.User get(1: types.UserId id) }
      #|
    ),
    "common/types.thrift": (
      #|typedef i64 UserId
      #|struct User { 1: required UserId id }
      #|
    ),
  }
  let (workspace, diagnostics) = @moonthrift.compile_workspace("api.thrift", path => {
    sources.get(path)
  })
  assert_eq(diagnostics, [])
  let generated = @codegen.generate_workspace(workspace)
  assert_true(generated.content.contains("pub(all) struct Request"))
  assert_true(generated.content.contains("user : CommonTypesUser"))
  assert_true(generated.content.contains("pub type CommonTypesUserId = Int64"))
  assert_true(generated.content.contains("pub(all) struct CommonTypesUser"))
  assert_true(generated.content.contains("id : CommonTypesUserId"))
  assert_true(generated.content.contains("pub struct ApiClient"))
}

///|
test "generator emits oneway runtime facades but defers inheritance" {
  let schema = @moonthrift.parse_idl(
    "service Base { void ping() }\nservice Child extends Base { void pong() }\nservice Events { oneway void emit(1: i32 value) }",
  )
  let generated = @codegen.generate_moonbit(schema)
  assert_true(generated.content.contains("pub struct BaseClient"))
  assert_true(!generated.content.contains("pub struct ChildClient"))
  assert_true(generated.content.contains("pub struct EventsClient"))
  assert_true(generated.content.contains("EventsClient::emit"))
  assert_true(generated.content.contains("@rpc.send_oneway"))
  assert_true(generated.content.contains("@rpc.process_once_optional"))
}

///|
test "generated client escapes a reserved method identifier" {
  let schema = @moonthrift.parse_idl("service Api { void method() }")
  let generated = @codegen.generate_moonbit(schema)
  assert_true(generated.content.contains("ApiClient::method_"))
  assert_true(generated.content.contains("method_ : (ApiMethodArgs)"))
  assert_true(generated.content.contains("name: \"method\""))
}
