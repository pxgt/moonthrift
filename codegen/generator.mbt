///|
/// One generated source artifact.
pub(all) struct GeneratedFile {
  path : String
  content : String
} derive(Debug, Eq)

///|
fn is_keyword(name : String) -> Bool {
  match name {
    "as"
    | "async"
    | "break"
    | "catch"
    | "const"
    | "continue"
    | "derive"
    | "else"
    | "enum"
    | "fn"
    | "for"
    | "guard"
    | "if"
    | "impl"
    | "import"
    | "in"
    | "let"
    | "loop"
    | "map"
    | "match"
    | "mut"
    | "priv"
    | "pub"
    | "raise"
    | "return"
    | "struct"
    | "suberror"
    | "test"
    | "trait"
    | "try"
    | "type"
    | "using"
    | "while"
    | "with" => true
    _ => false
  }
}

///|
fn value_name(name : String) -> String {
  if is_keyword(name) {
    "\{name}_"
  } else {
    name
  }
}

///|
fn type_name(name : String) -> String {
  let final_component = name.split(".").last().unwrap_or(name[:]).to_owned()
  let builder = StringBuilder()
  let mut upper_next = true
  for char in final_component {
    if char == '_' {
      upper_next = true
    } else if upper_next {
      builder.write_char(char.to_ascii_uppercase())
      upper_next = false
    } else {
      builder.write_char(char)
    }
  }
  let result = builder.to_string()
  if result == "" {
    "Generated"
  } else {
    result
  }
}

///|
/// Renders one IDL type as its idiomatic MoonBit representation.
pub fn render_type(ty : @moonthrift.TypeRef) -> String {
  match ty {
    Base(Bool) => "Bool"
    Base(Byte) => "Byte"
    Base(I16) | Base(I32) => "Int"
    Base(I64) => "Int64"
    Base(Double) => "Double"
    Base(String) => "String"
    Base(Binary) => "Bytes"
    Base(Void) => "Unit"
    Named(name) => type_name(name)
    List(element) | Set(element) => "Array[\{render_type(element)}]"
    Map(key, value) => "Map[\{render_type(key)}, \{render_type(value)}]"
  }
}

///|
fn escape_string(value : String) -> String {
  let builder = StringBuilder()
  builder.write_char('"')
  for char in value {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(char)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
fn render_const(value : @moonthrift.ConstValue) -> String {
  match value {
    BoolValue(value) => if value { "true" } else { "false" }
    IntegerValue(value) => value.to_string()
    DoubleValue(value) => value.to_string()
    StringValue(value) => escape_string(value)
    IdentifierValue(value) => value.replace_all(old=".", new="::")
    ListValue(values) => "[\{values.map(render_const).join(", ")}]"
    MapValue(entries) => {
      let rendered = entries.map(entry => {
        let (key, entry_value) = entry
        "\{render_const(key)}: \{render_const(entry_value)}"
      })
      "{ \{rendered.join(", ")} }"
    }
  }
}

///|
fn render_field(field : @moonthrift.Field) -> String {
  let ty = render_type(field.ty)
  let final_type = if field.requiredness is Optional { "\{ty}?" } else { ty }
  "  \{value_name(field.name)} : \{final_type}\n"
}

///|
fn render_record(
  output : StringBuilder,
  kind : String,
  name : String,
  fields : ArrayView[@moonthrift.Field],
) -> Unit {
  output.write_string("///|\n/// Generated from Thrift \{kind} `\{name}`.\n")
  if fields.length() == 0 {
    output.write_string("pub(all) struct \{type_name(name)} {}\n\n")
  } else {
    output.write_string("pub(all) struct \{type_name(name)} {\n")
    for field in fields {
      output.write_string(render_field(field))
    }
    output.write_string("} derive(Debug, Eq)\n\n")
  }
}

///|
fn render_enum(
  output : StringBuilder,
  name : String,
  members : ArrayView[@moonthrift.EnumMember],
) -> Unit {
  let generated_name = type_name(name)
  output.write_string("///|\npub(all) enum \{generated_name} {\n")
  for enum_member in members {
    output.write_string("  \{type_name(enum_member.name)}\n")
  }
  output.write_string("} derive(Debug, Eq)\n\n")
  output.write_string(
    "///|\npub fn \{generated_name}::to_thrift_i32(self : \{generated_name}) -> Int {\n",
  )
  output.write_string("  match self {\n")
  for enum_member in members {
    output.write_string(
      "    \{type_name(enum_member.name)} => \{enum_member.value}\n",
    )
  }
  output.write_string("  }\n}\n\n")
  output.write_string(
    "///|\npub fn \{generated_name}::from_thrift_i32(value : Int) -> \{generated_name}? {\n",
  )
  output.write_string("  match value {\n")
  for enum_member in members {
    output.write_string(
      "    \{enum_member.value} => Some(\{type_name(enum_member.name)})\n",
    )
  }
  output.write_string("    _ => None\n  }\n}\n\n")
}

///|
fn render_union(
  output : StringBuilder,
  name : String,
  fields : ArrayView[@moonthrift.Field],
) -> Unit {
  output.write_string("///|\npub(all) enum \{type_name(name)} {\n  Empty\n")
  for field in fields {
    output.write_string(
      "  \{type_name(field.name)}(\{render_type(field.ty)})\n",
    )
  }
  output.write_string("} derive(Debug, Eq)\n\n")
}

///|
fn render_function_models(
  output : StringBuilder,
  service_name : String,
  function : @moonthrift.FunctionDef,
) -> Unit {
  let prefix = "\{type_name(service_name)}\{type_name(function.name)}"
  render_record(
    output,
    "function arguments",
    "\{prefix}Args",
    function.arguments,
  )
  output.write_string("///|\npub(all) enum \{prefix}Result {\n")
  if function.return_type is Base(Void) {
    output.write_string("  Success\n")
  } else {
    output.write_string("  Success(\{render_type(function.return_type)})\n")
  }
  for field in function.throws {
    output.write_string(
      "  \{type_name(field.name)}(\{render_type(field.ty)})\n",
    )
  }
  output.write_string("} derive(Debug, Eq)\n\n")
}

///|
fn render_definition(
  output : StringBuilder,
  definition : @moonthrift.Definition,
) -> Unit {
  match definition {
    Const(name~, ty~, value~, ..) =>
      output.write_string(
        "///|\npub let \{value_name(name)} : \{render_type(ty)} = \{render_const(value)}\n\n",
      )
    Typedef(name~, target~, ..) =>
      output.write_string(
        "///|\npub type \{type_name(name)} = \{render_type(target)}\n\n",
      )
    Enum(name~, members~, ..) => render_enum(output, name, members)
    Struct(name~, fields~, ..) => render_record(output, "struct", name, fields)
    Exception(name~, fields~, ..) =>
      render_record(output, "exception", name, fields)
    Union(name~, fields~, ..) => render_union(output, name, fields)
    Service(name~, functions~, ..) => {
      output.write_string(
        "// Service models for `\{name}`. Transport dispatch is supplied by the application.\n\n",
      )
      for function in functions {
        render_function_models(output, name, function)
      }
    }
  }
}

///|
/// Generates portable MoonBit declarations for a parsed schema.
pub fn generate_moonbit(
  schema : @moonthrift.Schema,
  path? : String = "generated.mbt",
) -> GeneratedFile {
  let output = StringBuilder()
  output.write_string(
    "// Generated by MoonThrift from \{schema.source}. Do not edit by hand.\n\n",
  )
  for definition in schema.definitions {
    render_definition(output, definition)
  }
  let mut content = output.to_string()
  while content.has_suffix("\n\n") {
    content = content.unsafe_substring(start=0, end=content.length() - 1)
  }
  { path, content, }
}
