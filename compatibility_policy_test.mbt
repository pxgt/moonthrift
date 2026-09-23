///|
test "compatibility policies distinguish direction and apply suppression" {
  let before = @moonthrift.parse_idl("struct Account { 1: optional i64 id }")
  let after = @moonthrift.parse_idl("struct Account { 1: required i64 id }")
  let backward = @moonthrift.compare_schemas_with_policy(
    before,
    after,
    Backward,
    source="account.thrift",
  )
  assert_eq(backward.length(), 1)
  assert_true(backward[0].direction is BackwardDirection)
  assert_eq(backward[0].change.code, "MTHC106")
  assert_true(@moonthrift.has_blocking_compatibility_findings(backward))
  let forward = @moonthrift.compare_schemas_with_policy(before, after, Forward)
  assert_eq(forward.length(), 0)
  assert_true(!@moonthrift.has_blocking_compatibility_findings(forward))
  let full = @moonthrift.compare_schemas_with_policy(before, after, Full)
  assert_eq(full.length(), 1)
  let suppressed = @moonthrift.compare_schemas_with_policy(
    before,
    after,
    Full,
    suppressed=["MTHC106"],
  )
  assert_eq(suppressed.length(), 0)
  assert_true(!@moonthrift.has_blocking_compatibility_findings(suppressed))
}

///|
test "full policy reports both directional breaks in a fixed order" {
  let before = @moonthrift.parse_idl("struct User { 1: required i64 id }")
  let after = @moonthrift.parse_idl("struct User { 1: required string id }")
  let findings = @moonthrift.compare_schemas_with_policy(before, after, Full)
  assert_eq(findings.length(), 2)
  assert_true(findings[0].direction is BackwardDirection)
  assert_true(findings[1].direction is ForwardDirection)
  assert_eq(findings[0].change.code, "MTHC104")
  assert_eq(findings[1].change.code, "MTHC104")
  assert_true(@moonthrift.has_blocking_compatibility_findings(findings))
}

///|
test "compatibility reports escape output and retain stable ordering" {
  let before = @moonthrift.parse_idl("struct User { 1: required i64 id }")
  let after = @moonthrift.parse_idl("struct User { 1: required string id }")
  let findings = @moonthrift.compare_schemas_with_policy(
    before,
    after,
    Backward,
    source="api/user.thrift",
  )
  assert_eq(
    @moonthrift.render_compatibility_report(findings, Backward, Text),
    "api/user.thrift: backward: breaking[MTHC104] User.id#1: field type changed from Base(I64) to Base(String)\nbackward: blocked (1 finding(s))",
  )
  let json = @moonthrift.render_compatibility_report(
    findings,
    Backward,
    JsonFormat,
  )
  assert_eq(
    json, "{\"policy\":\"backward\",\"blocked\":true,\"findings\":[{\"direction\":\"backward\",\"source\":\"api/user.thrift\",\"code\":\"MTHC104\",\"kind\":\"breaking\",\"path\":\"User.id#1\",\"message\":\"field type changed from Base(I64) to Base(String)\"}]}",
  )
  let markdown = @moonthrift.render_compatibility_report(
    findings,
    Backward,
    Markdown,
  )
  assert_true(markdown.contains("| api/user.thrift | backward | breaking |"))
  let annotations = @moonthrift.render_compatibility_report(
    findings,
    Backward,
    GithubAnnotations,
  )
  assert_true(
    annotations.contains("::error file=api/user.thrift,title=MTHC104::"),
  )
}

///|
test "compatibility reports escape source paths for each target format" {
  let before = @moonthrift.parse_idl("struct User { 1: required i64 id }")
  let after = @moonthrift.parse_idl("struct User { 1: required string id }")
  let findings = @moonthrift.compare_schemas_with_policy(
    before,
    after,
    Backward,
    source="api/a,b|\"%\n.thrift",
  )
  let json = @moonthrift.render_compatibility_report(
    findings,
    Backward,
    JsonFormat,
  )
  assert_true(json.contains("a,b|\\\"%\\n.thrift"))
  let markdown = @moonthrift.render_compatibility_report(
    findings,
    Backward,
    Markdown,
  )
  assert_true(markdown.contains("a,b\\|\"% .thrift"))
  let annotations = @moonthrift.render_compatibility_report(
    findings,
    Backward,
    GithubAnnotations,
  )
  assert_true(annotations.contains("file=api/a%2Cb|\"%25%0A.thrift,"))
}
