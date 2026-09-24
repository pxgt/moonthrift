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
    | "method"
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
    Base(Uuid) => "Bytes"
    Base(Void) => "Unit"
    Named(name) => type_name(name)
    List(element) | Set(element) => "Array[\{render_type(element)}]"
    Map(key, value) => "Map[\{render_type(key)}, \{render_type(value)}]"
    CppType(inner, _) => render_type(inner)
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
fn find_type_definition(
  schema : @moonthrift.Schema,
  name : String,
) -> @moonthrift.Definition? {
  let generated_name = type_name(name)
  for definition in schema.definitions {
    if type_name(definition.name()) == generated_name {
      match definition {
        Const(..) | Service(..) => ()
        _ => return Some(definition)
      }
    }
  }
  None
}

///|
fn documentation(annotations : ArrayView[@moonthrift.Annotation]) -> String? {
  for annotation in annotations {
    if annotation.key == "moonbit.doc" {
      return annotation.value
    }
  }
  None
}

///|
fn render_doc_comment(output : StringBuilder, text : String) -> Unit {
  for line in text.split("\n") {
    let line = line.to_owned()
    if line == "" {
      output.write_string("///\n")
    } else {
      output.write_string("/// \{line}\n")
    }
  }
}

///|
fn render_member_doc_comment(output : StringBuilder, text : String) -> Unit {
  for line in text.split("\n") {
    let line = line.to_owned()
    if line == "" {
      output.write_string("  ///\n")
    } else {
      output.write_string("  /// \{line}\n")
    }
  }
}

///|
fn wire_type_name(
  schema : @moonthrift.Schema,
  ty : @moonthrift.TypeRef,
) -> String {
  match ty {
    Base(Bool) => "Bool"
    Base(Byte) => "Byte"
    Base(I16) => "I16"
    Base(I32) => "I32"
    Base(I64) => "I64"
    Base(Double) => "Double"
    Base(String) | Base(Binary) | Base(Uuid) => "Binary"
    Base(Void) => "Stop"
    List(_) => "List"
    Set(_) => "Set"
    Map(_, _) => "Map"
    CppType(inner, _) => wire_type_name(schema, inner)
    Named(name) =>
      match find_type_definition(schema, name) {
        Some(Typedef(target~, ..)) => wire_type_name(schema, target)
        Some(Enum(..)) => "I32"
        _ => "Struct"
      }
  }
}

///|
fn render_encode_value(
  schema : @moonthrift.Schema,
  ty : @moonthrift.TypeRef,
  expression : String,
) -> String {
  match ty {
    Base(Bool) => "BoolValue(\{expression})"
    Base(Byte) => "ByteValue(\{expression}.to_int())"
    Base(I16) => "I16Value(\{expression})"
    Base(I32) => "I32Value(\{expression})"
    Base(I64) => "I64Value(\{expression})"
    Base(Double) => "DoubleValue(\{expression})"
    Base(String) => "@protocol.string_value(\{expression})"
    Base(Binary) | Base(Uuid) => "BinaryValue(\{expression})"
    Base(Void) => "StructValue([])"
    CppType(inner, _) => render_encode_value(schema, inner, expression)
    Named(name) =>
      match find_type_definition(schema, name) {
        Some(Typedef(target~, ..)) =>
          render_encode_value(schema, target, expression)
        Some(Enum(..)) => "I32Value(\{expression}.to_thrift_i32())"
        _ => "\{expression}.to_thrift_value()"
      }
    List(element) => {
      let item = render_encode_value(schema, element, "item")
      "ListValue(element_type=\{wire_type_name(schema, element)}, values=\{expression}.map(item => \{item}))"
    }
    Set(element) => {
      let item = render_encode_value(schema, element, "item")
      "SetValue(element_type=\{wire_type_name(schema, element)}, values=\{expression}.map(item => \{item}))"
    }
    Map(key, value) => {
      let encoded_key = render_encode_value(schema, key, "key")
      let encoded_value = render_encode_value(schema, value, "value")
      "MapValue(key_type=\{wire_type_name(schema, key)}, value_type=\{wire_type_name(schema, value)}, entries=[for key, value in \{expression} => (\{encoded_key}, \{encoded_value})])"
    }
  }
}

///|
fn render_decode_value(
  schema : @moonthrift.Schema,
  ty : @moonthrift.TypeRef,
  expression : String,
) -> String {
  match ty {
    Base(Bool) => "\{expression}.require_bool()"
    Base(Byte) => "\{expression}.require_byte()"
    Base(I16) => "\{expression}.require_i16()"
    Base(I32) => "\{expression}.require_i32()"
    Base(I64) => "\{expression}.require_i64()"
    Base(Double) => "\{expression}.require_double()"
    Base(String) => "\{expression}.require_string()"
    Base(Binary) | Base(Uuid) => "\{expression}.require_binary()"
    Base(Void) => "()"
    CppType(inner, _) => render_decode_value(schema, inner, expression)
    Named(name) => {
      let generated_name = type_name(name)
      match find_type_definition(schema, name) {
        Some(Typedef(target~, ..)) =>
          render_decode_value(schema, target, expression)
        Some(Enum(..)) =>
          "match \{generated_name}::from_thrift_i32(\{expression}.require_i32()) { Some(value) => value; None => raise InvalidEnum(type_name=\{escape_string(generated_name)}, value=\{expression}.require_i32()) }"
        _ => "\{generated_name}::from_thrift_value(\{expression})"
      }
    }
    List(element) => {
      let item = render_decode_value(schema, element, "item")
      "\{expression}.require_list(\{wire_type_name(schema, element)}).map(item => \{item})"
    }
    Set(element) => {
      let item = render_decode_value(schema, element, "item")
      "\{expression}.require_set(\{wire_type_name(schema, element)}).map(item => \{item})"
    }
    Map(key, value) => {
      let decoded_key = render_decode_value(schema, key, "key")
      let decoded_value = render_decode_value(schema, value, "value")
      "Map(\{expression}.require_map(\{wire_type_name(schema, key)}, \{wire_type_name(schema, value)}).map(entry => { let (key, value) = entry; (\{decoded_key}, \{decoded_value}) }))"
    }
  }
}

///|
fn render_field(field : @moonthrift.Field) -> String {
  let output = StringBuilder()
  match documentation(field.annotations) {
    Some(text) => render_member_doc_comment(output, text)
    None => ()
  }
  let ty = render_type(field.ty)
  let final_type = if field.requiredness is Optional { "\{ty}?" } else { ty }
  output.write_string("  \{value_name(field.name)} : \{final_type}\n")
  output.to_string()
}

///|
fn render_record(
  output : StringBuilder,
  schema : @moonthrift.Schema,
  kind : String,
  name : String,
  fields : ArrayView[@moonthrift.Field],
  record_documentation : String?,
) -> Unit {
  output.write_string("///|\n")
  match record_documentation {
    Some(text) => render_doc_comment(output, text)
    None => ()
  }
  output.write_string("/// Generated from Thrift \{kind} `\{name}`.\n")
  if fields.length() == 0 {
    output.write_string("pub(all) struct \{type_name(name)} {}\n\n")
  } else {
    output.write_string("pub(all) struct \{type_name(name)} {\n")
    for field in fields {
      output.write_string(render_field(field))
    }
    output.write_string("} derive(Debug, Eq)\n\n")
  }
  render_record_codec(output, schema, name, fields)
}

///|
fn render_record_codec(
  output : StringBuilder,
  schema : @moonthrift.Schema,
  name : String,
  fields : ArrayView[@moonthrift.Field],
) -> Unit {
  let generated_name = type_name(name)
  output.write_string(
    "///|\n/// Converts this generated record to its schema-independent Thrift value.\n",
  )
  output.write_string(
    "pub fn \{generated_name}::to_thrift_value(self : \{generated_name}) -> @protocol.Value {\n",
  )
  if fields.length() == 0 {
    output.write_string("  ignore(self)\n")
  }
  output.write_string("  let fields : Array[@protocol.FieldValue] = []\n")
  for field in fields {
    let field_name = value_name(field.name)
    if field.requiredness is Optional {
      output.write_string("  match self.\{field_name} {\n")
      output.write_string(
        "    Some(value) => fields.push({ id: \{field.id}, value: \{render_encode_value(schema, field.ty, "value")} })\n",
      )
      output.write_string("    None => ()\n  }\n")
    } else {
      output.write_string(
        "  fields.push({ id: \{field.id}, value: \{render_encode_value(schema, field.ty, "self.\{field_name}")} })\n",
      )
    }
  }
  output.write_string("  StructValue(fields)\n}\n\n")
  output.write_string(
    "///|\n/// Builds a generated record from a schema-independent Thrift value.\n",
  )
  if fields.length() == 0 {
    // MoonBit currently warns that the required qualified empty-struct
    // literal is redundant even though unqualified braces parse as a map.
    output.write_string("#warnings(\"-unnecessary_annotation\")\n")
  }
  output.write_string(
    "pub fn \{generated_name}::from_thrift_value(value : @protocol.Value) -> \{generated_name} raise @protocol.ProtocolError {\n",
  )
  output.write_string("  let fields = value.require_struct()\n")
  for field in fields {
    output.write_string(
      "  let mut decoded_\{value_name(field.name)} : \{render_type(field.ty)}? = None\n",
    )
  }
  output.write_string("  for field in fields {\n    match field.id {\n")
  for field in fields {
    output.write_string(
      "      \{field.id} => decoded_\{value_name(field.name)} = Some(\{render_decode_value(schema, field.ty, "field.value")})\n",
    )
  }
  output.write_string("      _ => ()\n    }\n  }\n")
  if fields.length() == 0 {
    output.write_string("  \{generated_name}::{}\n")
  } else {
    output.write_string("  {\n")
    for field in fields {
      let field_name = value_name(field.name)
      let decoded_name = "decoded_\{field_name}"
      let value = if field.requiredness is Optional {
        decoded_name
      } else {
        match (field.requiredness, field.default_value) {
          (Default, Some(default_value)) =>
            "match \{decoded_name} { Some(value) => value; None => \{render_const(default_value)} }"
          _ =>
            "match \{decoded_name} { Some(value) => value; None => raise MissingRequiredField(type_name=\{escape_string(generated_name)}, field_id=\{field.id}, field_name=\{escape_string(field.name)}) }"
        }
      }
      output.write_string("    \{field_name}: \{value},\n")
    }
    output.write_string("  }\n")
  }
  output.write_string("}\n\n")
  output.write_string(
    "///|\npub fn \{generated_name}::encode_binary(self : \{generated_name}) -> Bytes raise @protocol.ProtocolError {\n  @protocol.encode_binary(self.to_thrift_value())\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::decode_binary(input : Bytes) -> \{generated_name} raise @protocol.ProtocolError {\n  \{generated_name}::from_thrift_value(@protocol.decode_binary(input, Struct))\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::encode_compact(self : \{generated_name}) -> Bytes raise @protocol.ProtocolError {\n  @protocol.encode_compact(self.to_thrift_value())\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::decode_compact(input : Bytes) -> \{generated_name} raise @protocol.ProtocolError {\n  \{generated_name}::from_thrift_value(@protocol.decode_compact(input, Struct))\n}\n\n",
  )
}

///|
fn render_enum(
  output : StringBuilder,
  name : String,
  members : ArrayView[@moonthrift.EnumMember],
  annotations : ArrayView[@moonthrift.Annotation],
) -> Unit {
  let generated_name = type_name(name)
  output.write_string("///|\n")
  match documentation(annotations) {
    Some(text) => render_doc_comment(output, text)
    None => ()
  }
  output.write_string("pub(all) enum \{generated_name} {\n")
  for enum_member in members {
    match documentation(enum_member.annotations) {
      Some(text) => render_member_doc_comment(output, text)
      None => ()
    }
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
  output.write_string(
    "///|\npub fn \{generated_name}::to_thrift_value(self : \{generated_name}) -> @protocol.Value {\n  I32Value(self.to_thrift_i32())\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::from_thrift_value(value : @protocol.Value) -> \{generated_name} raise @protocol.ProtocolError {\n  let raw = value.require_i32()\n  match \{generated_name}::from_thrift_i32(raw) {\n    Some(value) => value\n    None => raise InvalidEnum(type_name=\{escape_string(generated_name)}, value=raw)\n  }\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::encode_binary(self : \{generated_name}) -> Bytes raise @protocol.ProtocolError {\n  @protocol.encode_binary(self.to_thrift_value())\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::decode_binary(input : Bytes) -> \{generated_name} raise @protocol.ProtocolError {\n  \{generated_name}::from_thrift_value(@protocol.decode_binary(input, I32))\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::encode_compact(self : \{generated_name}) -> Bytes raise @protocol.ProtocolError {\n  @protocol.encode_compact(self.to_thrift_value())\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::decode_compact(input : Bytes) -> \{generated_name} raise @protocol.ProtocolError {\n  \{generated_name}::from_thrift_value(@protocol.decode_compact(input, I32))\n}\n\n",
  )
}

///|
fn render_union(
  output : StringBuilder,
  schema : @moonthrift.Schema,
  name : String,
  fields : ArrayView[@moonthrift.Field],
  annotations : ArrayView[@moonthrift.Annotation],
) -> Unit {
  let generated_name = type_name(name)
  output.write_string("///|\n")
  match documentation(annotations) {
    Some(text) => render_doc_comment(output, text)
    None => ()
  }
  output.write_string("pub(all) enum \{generated_name} {\n  Empty\n")
  for field in fields {
    match documentation(field.annotations) {
      Some(text) => render_member_doc_comment(output, text)
      None => ()
    }
    output.write_string(
      "  \{type_name(field.name)}(\{render_type(field.ty)})\n",
    )
  }
  output.write_string("} derive(Debug, Eq)\n\n")
  output.write_string(
    "///|\npub fn \{generated_name}::to_thrift_value(self : \{generated_name}) -> @protocol.Value {\n  match self {\n    Empty => StructValue([])\n",
  )
  for field in fields {
    output.write_string(
      "    \{type_name(field.name)}(value) => StructValue([{ id: \{field.id}, value: \{render_encode_value(schema, field.ty, "value")} }])\n",
    )
  }
  output.write_string("  }\n}\n\n")
  output.write_string(
    "///|\npub fn \{generated_name}::from_thrift_value(value : @protocol.Value) -> \{generated_name} raise @protocol.ProtocolError {\n  let fields = value.require_struct()\n  let mut result : \{generated_name}? = None\n  for field in fields {\n    match field.id {\n",
  )
  for field in fields {
    output.write_string(
      "      \{field.id} => {\n        if result is Some(_) {\n          raise InvalidValue(\{escape_string("union \{generated_name} contains multiple known fields")})\n        }\n        result = Some(\{type_name(field.name)}(\{render_decode_value(schema, field.ty, "field.value")}))\n      }\n",
    )
  }
  output.write_string(
    "      _ => ()\n    }\n  }\n  match result {\n    Some(value) => value\n    None => Empty\n  }\n}\n\n",
  )
  render_value_codec_conveniences(output, generated_name, "Struct")
}

///|
fn render_value_codec_conveniences(
  output : StringBuilder,
  generated_name : String,
  wire_type : String,
) -> Unit {
  output.write_string(
    "///|\npub fn \{generated_name}::encode_binary(self : \{generated_name}) -> Bytes raise @protocol.ProtocolError {\n  @protocol.encode_binary(self.to_thrift_value())\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::decode_binary(input : Bytes) -> \{generated_name} raise @protocol.ProtocolError {\n  \{generated_name}::from_thrift_value(@protocol.decode_binary(input, \{wire_type}))\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::encode_compact(self : \{generated_name}) -> Bytes raise @protocol.ProtocolError {\n  @protocol.encode_compact(self.to_thrift_value())\n}\n\n",
  )
  output.write_string(
    "///|\npub fn \{generated_name}::decode_compact(input : Bytes) -> \{generated_name} raise @protocol.ProtocolError {\n  \{generated_name}::from_thrift_value(@protocol.decode_compact(input, \{wire_type}))\n}\n\n",
  )
}

///|
fn render_function_models(
  output : StringBuilder,
  schema : @moonthrift.Schema,
  service_name : String,
  service_documentation : String?,
  function : @moonthrift.FunctionDef,
) -> Unit {
  let prefix = "\{type_name(service_name)}\{type_name(function.name)}"
  let model_documentation = match
    (service_documentation, documentation(function.annotations)) {
    (Some(service_doc), Some(function_doc)) =>
      Some("\{service_doc}\n\n\{function_doc}")
    (Some(service_doc), None) => Some(service_doc)
    (None, Some(function_doc)) => Some(function_doc)
    (None, None) => None
  }
  render_record(
    output,
    schema,
    "function arguments",
    "\{prefix}Args",
    function.arguments,
    model_documentation,
  )
  output.write_string("///|\n")
  match model_documentation {
    Some(text) => render_doc_comment(output, text)
    None => ()
  }
  output.write_string("pub(all) enum \{prefix}Result {\n")
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
  render_function_result_codec(output, schema, prefix, function)
}

///|
fn render_function_result_codec(
  output : StringBuilder,
  schema : @moonthrift.Schema,
  prefix : String,
  function : @moonthrift.FunctionDef,
) -> Unit {
  let result_name = "\{prefix}Result"
  output.write_string(
    "///|\npub fn \{result_name}::to_thrift_value(self : \{result_name}) -> @protocol.Value {\n  match self {\n",
  )
  if function.return_type is Base(Void) {
    output.write_string("    Success => StructValue([])\n")
  } else {
    output.write_string(
      "    Success(value) => StructValue([{ id: 0, value: \{render_encode_value(schema, function.return_type, "value")} }])\n",
    )
  }
  for field in function.throws {
    output.write_string(
      "    \{type_name(field.name)}(value) => StructValue([{ id: \{field.id}, value: \{render_encode_value(schema, field.ty, "value")} }])\n",
    )
  }
  output.write_string("  }\n}\n\n")
  output.write_string(
    "///|\npub fn \{result_name}::from_thrift_value(value : @protocol.Value) -> \{result_name} raise @protocol.ProtocolError {\n  let fields = value.require_struct()\n",
  )
  if function.return_type is Base(Void) && function.throws.length() == 0 {
    output.write_string("  let result : \{result_name}? = None\n")
  } else {
    output.write_string("  let mut result : \{result_name}? = None\n")
  }
  output.write_string("  for field in fields {\n    match field.id {\n")
  if !(function.return_type is Base(Void)) {
    output.write_string(
      "      0 => {\n        if result is Some(_) {\n          raise InvalidValue(\{escape_string("result \{result_name} contains multiple known fields")})\n        }\n        result = Some(Success(\{render_decode_value(schema, function.return_type, "field.value")}))\n      }\n",
    )
  }
  for field in function.throws {
    output.write_string(
      "      \{field.id} => {\n        if result is Some(_) {\n          raise InvalidValue(\{escape_string("result \{result_name} contains multiple known fields")})\n        }\n        result = Some(\{type_name(field.name)}(\{render_decode_value(schema, field.ty, "field.value")}))\n      }\n",
    )
  }
  output.write_string("      _ => ()\n    }\n  }\n")
  if function.return_type is Base(Void) {
    output.write_string(
      "  match result {\n    Some(value) => value\n    None => Success\n  }\n}\n\n",
    )
  } else {
    output.write_string(
      "  match result {\n    Some(value) => value\n    None => raise InvalidValue(\{escape_string("result \{result_name} has no recognized field")})\n  }\n}\n\n",
    )
  }
  render_value_codec_conveniences(output, result_name, "Struct")
}

///|
fn render_definition(
  output : StringBuilder,
  schema : @moonthrift.Schema,
  definition : @moonthrift.Definition,
) -> Unit {
  match definition {
    Const(name~, ty~, value~, annotations~, ..) => {
      output.write_string("///|\n")
      match documentation(annotations) {
        Some(text) => render_doc_comment(output, text)
        None => ()
      }
      output.write_string(
        "pub let \{value_name(name)} : \{render_type(ty)} = \{render_const(value)}\n\n",
      )
    }
    Typedef(name~, target~, annotations~, ..) => {
      output.write_string("///|\n")
      match documentation(annotations) {
        Some(text) => render_doc_comment(output, text)
        None => ()
      }
      output.write_string(
        "pub type \{type_name(name)} = \{render_type(target)}\n\n",
      )
    }
    Enum(name~, members~, annotations~, ..) =>
      render_enum(output, name, members, annotations)
    Struct(name~, fields~, annotations~, ..) =>
      render_record(
        output,
        schema,
        "struct",
        name,
        fields,
        documentation(annotations),
      )
    Exception(name~, fields~, annotations~, ..) =>
      render_record(
        output,
        schema,
        "exception",
        name,
        fields,
        documentation(annotations),
      )
    Union(name~, fields~, annotations~, ..) =>
      render_union(output, schema, name, fields, annotations)
    Service(name~, extends~, functions~, annotations~, ..) => {
      let service_documentation = documentation(annotations)
      output.write_string(
        "// Service models for `\{name}`. Runtime facades are emitted for non-inherited services.\n\n",
      )
      for function in functions {
        render_function_models(
          output, schema, name, service_documentation, function,
        )
      }
      render_service_rpc_runtime(output, name, extends, functions)
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
    render_definition(output, schema, definition)
  }
  let mut content = output.to_string()
  while content.has_suffix("\n\n") {
    content = content.unsafe_substring(start=0, end=content.length() - 1)
  }
  { path, content, }
}
