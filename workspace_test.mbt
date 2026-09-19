///|
test "workspace loads normalized relative includes and links qualified names" {
  let sources : Map[String, String] = {
    "schemas/api.thrift": (
      #|include "../common/types.thrift"
      #|struct Request { 1: required types.User user }
      #|service Api extends types.Base { types.User get(1: i64 id) }
      #|
    ),
    "common/types.thrift": (
      #|struct User { 1: required i64 id }
      #|service Base { void ping() }
      #|
    ),
  }
  let (workspace, diagnostics) = @moonthrift.compile_workspace(
    "./schemas/api.thrift",
    path => sources.get(path),
  )
  assert_eq(diagnostics, [])
  assert_eq(workspace.root, "schemas/api.thrift")
  assert_eq(workspace.documents.length(), 2)
  assert_eq(workspace.documents[0].source, "schemas/api.thrift")
  assert_eq(workspace.documents[1].source, "common/types.thrift")
}

///|
test "workspace loads each included source once" {
  let sources : Map[String, String] = {
    "root.thrift": (
      #|include "shared.thrift"
      #|include "./shared.thrift"
      #|struct Root { 1: shared.Value value }
      #|
    ),
    "shared.thrift": "struct Value { 1: i32 count }",
  }
  let (workspace, diagnostics) = @moonthrift.compile_workspace("root.thrift", path => {
    sources.get(path)
  })
  assert_eq(diagnostics, [])
  assert_eq(workspace.documents.length(), 2)
}

///|
test "workspace diagnoses missing sources and include cycles" {
  let sources : Map[String, String] = {
    "root.thrift": (
      #|include "child.thrift"
      #|include "missing.thrift"
      #|struct Root { 1: child.Value value }
      #|
    ),
    "child.thrift": (
      #|include "root.thrift"
      #|struct Value { 1: i32 count }
      #|
    ),
  }
  let (_, diagnostics) = @moonthrift.compile_workspace("root.thrift", path => {
    sources.get(path)
  })
  let codes = diagnostics.map(item => item.code)
  assert_true(codes.contains("MTH201"))
  assert_true(codes.contains("MTH202"))
}

///|
test "workspace diagnoses alias conflicts and unresolved qualified names" {
  let sources : Map[String, String] = {
    "root.thrift": (
      #|include "left/shared.thrift"
      #|include "right/shared.thrift"
      #|struct Root {
      #|  1: shared.Missing missing
      #|  2: absent.Value unknown_alias
      #|}
      #|
    ),
    "left/shared.thrift": "struct Value { 1: i32 count }",
    "right/shared.thrift": "service Missing { void ping() }",
  }
  let (_, diagnostics) = @moonthrift.compile_workspace("root.thrift", path => {
    sources.get(path)
  })
  let codes = diagnostics.map(item => item.code)
  assert_true(codes.contains("MTH203"))
  assert_true(codes.contains("MTH204"))
  assert_true(codes.contains("MTH205"))
}
