///|
fn usage() -> String {
  let text =
    #|moonthrift - Apache Thrift IDL and protocol tools for MoonBit
    #|
    #|Usage:
    #|  moon run cmd/main
    #|  moon run cmd/main -- check <schema.thrift>
    #|  moon run cmd/main -- inspect <schema.thrift>
    #|  moon run cmd/main -- generate <schema.thrift> [output.mbt]
    #|  moon run cmd/main -- diff <before.thrift> <after.thrift>
    #|  moon run cmd/main -- compat [--policy backward|forward|full]
    #|    [--format text|json|markdown|github] [--suppress MTHC###]
    #|    [--report output] <before-file-or-dir> <after-file-or-dir>
    #|
    #|With no arguments, the command runs a schema and compact-protocol demo.
    #|
  text
}

///|
fn read_schema(path : String) -> @lib.Schema raise {
  @lib.parse_idl(@fs.read_file_to_string(path), source=path)
}

///|
fn read_workspace(
  path : String,
) -> (@lib.SchemaWorkspace, Array[@lib.Diagnostic]) raise {
  @lib.compile_workspace(path, candidate => {
    try @fs.read_file_to_string(candidate) catch {
      _ => None
    } noraise {
      content => Some(content)
    }
  })
}

///|
fn print_diagnostics(diagnostics : Array[@lib.Diagnostic]) -> Unit {
  for item in diagnostics {
    println(item.to_text())
  }
}

///|
fn run_check(path : String) -> Unit raise {
  let (workspace, diagnostics) = read_workspace(path)
  print_diagnostics(diagnostics)
  if @lib.has_errors(diagnostics) {
    println("check failed with \{diagnostics.length()} diagnostic(s)")
    @sys.exit(2)
  }
  let definition_count = workspace.documents.fold(init=0, (count, schema) => {
    count + schema.definitions.length()
  })
  println(
    "OK: \{workspace.documents.length()} document(s), \{definition_count} definition(s), no semantic errors",
  )
}

///|
fn run_demo() -> Unit raise {
  let idl =
    #|namespace mbt demo
    #|struct User { 1: required i64 id, 2: optional string name }
    #|service Users { User get(1: i64 id) }
    #|
  let (schema, diagnostics) = @lib.compile_idl(idl, source="<demo>")
  println(schema.to_outline())
  print_diagnostics(diagnostics)
  let value : @protocol.Value = StructValue([
    { id: 1, value: I64Value(7L), },
    { id: 2, value: BinaryValue(b"MoonBit"), },
  ])
  let encoded = @protocol.encode_compact(value)
  let decoded = @protocol.decode_compact(encoded, Struct)
  println(
    "compact round trip: \{encoded.length()} bytes, equal=\{decoded == value}",
  )
}

///|
fn parse_policy(value : String) -> @lib.CompatibilityPolicy raise {
  match value {
    "backward" => Backward
    "forward" => Forward
    "full" => Full
    _ => raise Failure("unknown compatibility policy `\{value}`")
  }
}

///|
fn parse_format(value : String) -> @lib.CompatibilityFormat raise {
  match value {
    "text" => Text
    "json" => JsonFormat
    "markdown" => Markdown
    "github" => GithubAnnotations
    _ => raise Failure("unknown compatibility format `\{value}`")
  }
}

///|
fn known_compatibility_rule(value : String) -> Bool {
  match value {
    "MTHC101"
    | "MTHC102"
    | "MTHC103"
    | "MTHC104"
    | "MTHC105"
    | "MTHC106"
    | "MTHC107"
    | "MTHC108"
    | "MTHC109"
    | "MTHC110"
    | "MTHC111"
    | "MTHC112"
    | "MTHC113"
    | "MTHC114"
    | "MTHC115"
    | "MTHC116"
    | "MTHC117" => true
    _ => false
  }
}

///|
fn collect_thrift_files(
  root : String,
  relative : String,
  files : Map[String, String],
  depth : Int,
) -> Unit raise {
  if depth > 32 {
    raise Failure("schema directory depth exceeds 32: \{root}")
  }
  let directory = if relative == "" { root } else { "\{root}/\{relative}" }
  let names = @fs.read_dir(directory).to_owned()
  names.sort()
  for name in names {
    if name != ".git" && name != "_build" && name != ".mooncakes" {
      let child = if relative == "" { name } else { "\{relative}/\{name}" }
      let path = "\{root}/\{child}"
      if @fs.is_dir(path) {
        collect_thrift_files(root, child, files, depth + 1)
      } else if name.has_suffix(".thrift") && @fs.is_file(path) {
        files[child] = path
      }
    }
  }
}

///|
fn schema_or_empty(path : String?, source : String) -> @lib.Schema raise {
  match path {
    Some(path) => {
      let (workspace, diagnostics) = read_workspace(path)
      if @lib.has_errors(diagnostics) {
        print_diagnostics(diagnostics)
        raise Failure("invalid schema `\{path}`")
      }
      workspace.documents[0]
    }
    None => @lib.parse_idl("", source~)
  }
}

///|
fn run_compat(args : Array[String]) -> Unit raise {
  let mut policy : @lib.CompatibilityPolicy = Backward
  let mut format : @lib.CompatibilityFormat = Text
  let suppressed : Array[String] = []
  let mut report : String? = None
  let inputs : Array[String] = []
  let mut index = 2
  while index < args.length() {
    let option = args[index]
    match option {
      "--policy" | "--format" | "--suppress" | "--report" => {
        if index + 1 >= args.length() {
          raise Failure("\{option} requires a value")
        }
        let value = args[index + 1]
        match option {
          "--policy" => policy = parse_policy(value)
          "--format" => format = parse_format(value)
          "--suppress" => {
            if !known_compatibility_rule(value) {
              raise Failure("unknown suppression rule `\{value}`")
            }
            suppressed.push(value)
          }
          "--report" => report = Some(value)
          _ => ()
        }
        index += 2
      }
      _ => {
        if option.has_prefix("--") {
          raise Failure("unknown option `\{option}`")
        }
        inputs.push(option)
        index += 1
      }
    }
  }
  if inputs.length() != 2 {
    raise Failure(
      "compat expects before and after .thrift files or directories",
    )
  }
  let before = inputs[0]
  let after = inputs[1]
  let before_is_dir = @fs.is_dir(before)
  let after_is_dir = @fs.is_dir(after)
  if before_is_dir != after_is_dir {
    raise Failure("compat inputs must both be files or both be directories")
  }
  let findings : Array[@lib.CompatibilityFinding] = []
  if before_is_dir {
    let before_files : Map[String, String] = Map([])
    let after_files : Map[String, String] = Map([])
    collect_thrift_files(before, "", before_files, 0)
    collect_thrift_files(after, "", after_files, 0)
    let names : Array[String] = []
    for name, _ in before_files {
      names.push(name)
    }
    for name, _ in after_files {
      if !names.contains(name) {
        names.push(name)
      }
    }
    names.sort()
    for name in names {
      let source = "\{after}/\{name}".replace_all(old="\\", new="/")
      let old_schema = schema_or_empty(before_files.get(name), source)
      let new_schema = schema_or_empty(after_files.get(name), source)
      findings.append(
        @lib.compare_schemas_with_policy(
          old_schema,
          new_schema,
          policy,
          source~,
          suppressed~,
        ),
      )
    }
  } else {
    if !@fs.is_file(before) || !@fs.is_file(after) {
      raise Failure("compat file inputs must exist")
    }
    let source = after.replace_all(old="\\", new="/")
    findings.append(
      @lib.compare_schemas_with_policy(
        schema_or_empty(Some(before), source),
        schema_or_empty(Some(after), source),
        policy,
        source~,
        suppressed~,
      ),
    )
  }
  let output = @lib.render_compatibility_report(findings, policy, format)
  match report {
    Some(path) => {
      @fs.write_string_to_file(path, "\{output}\n")
      println("compatibility report written to \{path}")
    }
    None => println(output)
  }
  if @lib.has_blocking_compatibility_findings(findings) {
    @sys.exit(3)
  }
}

///|
fn run(args : Array[String]) -> Unit raise {
  if args.length() <= 1 {
    run_demo()
    return
  }
  match args[1] {
    "help" | "--help" | "-h" => println(usage())
    "check" =>
      if args.length() != 3 {
        raise Failure("check expects one .thrift file")
      } else {
        run_check(args[2])
      }
    "inspect" =>
      if args.length() != 3 {
        raise Failure("inspect expects one .thrift file")
      } else {
        let (workspace, diagnostics) = read_workspace(args[2])
        for schema in workspace.documents {
          println("== \{schema.source} ==")
          println(schema.to_outline())
        }
        print_diagnostics(diagnostics)
      }
    "generate" =>
      if args.length() < 3 || args.length() > 4 {
        raise Failure("generate expects an input and optional output path")
      } else {
        let input = args[2]
        let output = if args.length() == 4 { args[3] } else { "generated.mbt" }
        let (workspace, diagnostics) = read_workspace(input)
        if @lib.has_errors(diagnostics) {
          print_diagnostics(diagnostics)
          raise Failure("refusing to generate from an invalid schema")
        }
        let generated = @codegen.generate_workspace(workspace, path=output)
        @fs.write_string_to_file(output, generated.content)
        println("generated \{output}")
      }
    "diff" =>
      if args.length() != 4 {
        raise Failure("diff expects an old and new .thrift file")
      } else {
        let changes = @lib.compare_schemas(
          read_schema(args[2]),
          read_schema(args[3]),
        )
        for item in changes {
          println(item.to_text())
        }
        if @lib.has_breaking_changes(changes) {
          @sys.exit(3)
        }
      }
    "compat" => run_compat(args)
    command => raise Failure("unknown command `\{command}`; run with --help")
  }
}

///|
fn main {
  try run(@env.args()) catch {
    error => {
      println("moonthrift: \{error}")
      @sys.exit(1)
    }
  } noraise {
    _ => ()
  }
}
