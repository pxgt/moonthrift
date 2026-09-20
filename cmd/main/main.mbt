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
