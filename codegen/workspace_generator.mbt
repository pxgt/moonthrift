///|
fn normalize_codegen_path(path : String) -> String {
  let portable = path.replace_all(old="\\", new="/")
  let absolute = portable.has_prefix("/")
  let parts : Array[String] = []
  for raw_part in portable.split("/") {
    let part = raw_part.to_owned()
    match part {
      "" | "." => ()
      ".." =>
        match parts.last() {
          Some(previous) if previous != ".." => ignore(parts.pop())
          _ => parts.push(part)
        }
      _ => parts.push(part)
    }
  }
  let normalized = parts.join("/")
  if absolute {
    "/\{normalized}"
  } else {
    normalized
  }
}

///|
fn codegen_parent(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
fn resolve_codegen_include(importer : String, include_path : String) -> String {
  let parent = codegen_parent(importer)
  normalize_codegen_path(
    if parent == "" {
      include_path
    } else {
      "\{parent}/\{include_path}"
    },
  )
}

///|
fn codegen_include_alias(path : String) -> String {
  let filename = normalize_codegen_path(path)
    .split("/")
    .last()
    .unwrap_or(path[:])
    .to_owned()
  filename.strip_suffix(".thrift").unwrap_or(filename[:]).to_owned()
}

///|
fn document_type_prefix(root : String, path : String) -> String {
  if root == path {
    return ""
  }
  let stem = path.strip_suffix(".thrift").unwrap_or(path[:]).to_owned()
  type_name(
    stem
    .replace_all(old="/", new="_")
    .replace_all(old=".", new="_")
    .replace_all(old="-", new="_"),
  )
}

///|
fn document_value_prefix(root : String, path : String) -> String {
  if root == path {
    ""
  } else {
    let stem = path.strip_suffix(".thrift").unwrap_or(path[:]).to_owned()
    "\{stem.replace_all(old="/", new="_").replace_all(old=".", new="_").replace_all(old="-", new="_")}_"
  }
}

///|
fn included_document_path(
  schema : @moonthrift.Schema,
  name : String,
) -> String? {
  for header in schema.headers {
    match header {
      Include(path~, ..) if codegen_include_alias(path) == name =>
        return Some(resolve_codegen_include(schema.source, path))
      _ => ()
    }
  }
  None
}

///|
fn rename_workspace_type(
  workspace : @moonthrift.SchemaWorkspace,
  schema : @moonthrift.Schema,
  name : String,
) -> String {
  match name.split_once(".") {
    None =>
      "\{document_type_prefix(workspace.root, schema.source)}\{type_name(name)}"
    Some((include_view, symbol_view)) => {
      let include_name = include_view.to_owned()
      let symbol = symbol_view.to_owned()
      match included_document_path(schema, include_name) {
        Some(path) =>
          "\{document_type_prefix(workspace.root, path)}\{type_name(symbol)}"
        None => type_name(name)
      }
    }
  }
}

///|
fn workspace_type(
  workspace : @moonthrift.SchemaWorkspace,
  schema : @moonthrift.Schema,
  ty : @moonthrift.TypeRef,
) -> @moonthrift.TypeRef {
  match ty {
    Base(base) => Base(base)
    Named(name) => Named(rename_workspace_type(workspace, schema, name))
    List(element) => List(workspace_type(workspace, schema, element))
    Set(element) => Set(workspace_type(workspace, schema, element))
    Map(key, value) =>
      Map(
        workspace_type(workspace, schema, key),
        workspace_type(workspace, schema, value),
      )
    CppType(inner, cpp_name) =>
      CppType(workspace_type(workspace, schema, inner), cpp_name)
  }
}

///|
fn workspace_field(
  workspace : @moonthrift.SchemaWorkspace,
  schema : @moonthrift.Schema,
  field : @moonthrift.Field,
) -> @moonthrift.Field {
  {
    id: field.id,
    requiredness: field.requiredness,
    ty: workspace_type(workspace, schema, field.ty),
    name: field.name,
    default_value: field.default_value,
    annotations: field.annotations,
    span: field.span,
  }
}

///|
fn workspace_fields(
  workspace : @moonthrift.SchemaWorkspace,
  schema : @moonthrift.Schema,
  fields : ArrayView[@moonthrift.Field],
) -> Array[@moonthrift.Field] {
  fields.map(field => workspace_field(workspace, schema, field))
}

///|
fn workspace_function(
  workspace : @moonthrift.SchemaWorkspace,
  schema : @moonthrift.Schema,
  function : @moonthrift.FunctionDef,
) -> @moonthrift.FunctionDef {
  {
    name: function.name,
    return_type: workspace_type(workspace, schema, function.return_type),
    arguments: workspace_fields(workspace, schema, function.arguments),
    throws: workspace_fields(workspace, schema, function.throws),
    oneway: function.oneway,
    annotations: function.annotations,
    span: function.span,
  }
}

///|
fn workspace_definition(
  workspace : @moonthrift.SchemaWorkspace,
  schema : @moonthrift.Schema,
  definition : @moonthrift.Definition,
) -> @moonthrift.Definition {
  let type_prefix = document_type_prefix(workspace.root, schema.source)
  match definition {
    Const(name~, ty~, value~, annotations~, span~) =>
      Const(
        name="\{document_value_prefix(workspace.root, schema.source)}\{name}",
        ty=workspace_type(workspace, schema, ty),
        value~,
        annotations~,
        span~,
      )
    Typedef(name~, target~, annotations~, span~) =>
      Typedef(
        name="\{type_prefix}\{type_name(name)}",
        target=workspace_type(workspace, schema, target),
        annotations~,
        span~,
      )
    Enum(name~, members~, annotations~, span~) =>
      Enum(
        name="\{type_prefix}\{type_name(name)}",
        members~,
        annotations~,
        span~,
      )
    Struct(name~, fields~, annotations~, span~) =>
      Struct(
        name="\{type_prefix}\{type_name(name)}",
        fields=workspace_fields(workspace, schema, fields),
        annotations~,
        span~,
      )
    Union(name~, fields~, annotations~, span~) =>
      Union(
        name="\{type_prefix}\{type_name(name)}",
        fields=workspace_fields(workspace, schema, fields),
        annotations~,
        span~,
      )
    Exception(name~, fields~, annotations~, span~) =>
      Exception(
        name="\{type_prefix}\{type_name(name)}",
        fields=workspace_fields(workspace, schema, fields),
        annotations~,
        span~,
      )
    Service(name~, extends~, functions~, annotations~, span~) =>
      Service(
        name="\{type_prefix}\{type_name(name)}",
        extends=extends.map(base => {
          rename_workspace_type(workspace, schema, base)
        }),
        functions=functions.map(function => {
          workspace_function(workspace, schema, function)
        }),
        annotations~,
        span~,
      )
  }
}

///|
/// Generates one collision-resistant MoonBit model file for a linked schema
/// workspace. Definitions from included documents receive a deterministic path
/// prefix, while root definitions keep their original generated names.
pub fn generate_workspace(
  workspace : @moonthrift.SchemaWorkspace,
  path? : String = "generated.mbt",
) -> GeneratedFile {
  let definitions : Array[@moonthrift.Definition] = []
  for schema in workspace.documents {
    for definition in schema.definitions {
      definitions.push(workspace_definition(workspace, schema, definition))
    }
  }
  generate_moonbit({ source: workspace.root, headers: [], definitions, }, path~)
}
