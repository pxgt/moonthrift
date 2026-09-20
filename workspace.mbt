///|
/// Provides source text for a normalized logical Thrift path.
///
/// Returning `None` reports a source-not-found diagnostic. The loader remains
/// caller-owned so this package stays portable across every stable backend.
pub type SourceLoader = (String) -> String?

///|
/// A recursively loaded set of Thrift documents rooted at one entry schema.
/// Documents are ordered deterministically with the root first, followed by
/// includes in source order. Each normalized path is loaded at most once.
pub(all) struct SchemaWorkspace {
  root : String
  documents : Array[Schema]
} derive(Debug, Eq)

///|
fn normalize_schema_path(path : String) -> String {
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
fn schema_parent(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
fn resolve_include_path(importer : String, include_path : String) -> String {
  let parent = schema_parent(importer)
  normalize_schema_path(
    if parent == "" {
      include_path
    } else {
      "\{parent}/\{include_path}"
    },
  )
}

///|
fn include_alias(path : String) -> String {
  let normalized = normalize_schema_path(path)
  let filename = normalized
    .split("/")
    .last()
    .unwrap_or(normalized[:])
    .to_owned()
  filename.strip_suffix(".thrift").unwrap_or(filename[:]).to_owned()
}

///|
fn find_document(documents : ArrayView[Schema], path : String) -> Schema? {
  for document in documents {
    if document.source == path {
      return Some(document)
    }
  }
  None
}

///|
fn push_workspace_diagnostic(
  diagnostics : Array[Diagnostic],
  code : String,
  message : String,
  span : Span,
) -> Unit {
  diagnostics.push(diagnostic(code, message, span))
}

///|
fn load_workspace_document(
  path : String,
  requested_at : Span,
  loader : SourceLoader,
  documents : Array[Schema],
  active : Array[String],
  diagnostics : Array[Diagnostic],
) -> Unit raise IdlError {
  let normalized = normalize_schema_path(path)
  if active.contains(normalized) {
    let chain = active.copy()
    chain.push(normalized)
    push_workspace_diagnostic(
      diagnostics,
      "MTH202",
      "include cycle detected: \{chain.join(" -> ")}",
      requested_at,
    )
    return
  }
  if find_document(documents, normalized) is Some(_) {
    return
  }
  guard loader(normalized) is Some(input) else {
    push_workspace_diagnostic(
      diagnostics,
      "MTH201",
      "included source `\{normalized}` was not found",
      requested_at,
    )
    return
  }
  let schema = parse_idl(input, source=normalized)
  documents.push(schema)
  active.push(normalized)
  for header in schema.headers {
    match header {
      Include(path=child, span~) =>
        load_workspace_document(
          resolve_include_path(normalized, child),
          span,
          loader,
          documents,
          active,
          diagnostics,
        )
      _ => ()
    }
  }
  ignore(active.pop())
}

///|
fn direct_include_aliases(
  schema : Schema,
  diagnostics : Array[Diagnostic],
) -> Map[String, String] {
  let aliases : Map[String, String] = Map([])
  for header in schema.headers {
    match header {
      Include(path~, span~) => {
        let include_name = include_alias(path)
        let target = resolve_include_path(schema.source, path)
        match aliases.get(include_name) {
          Some(previous) if previous != target =>
            push_workspace_diagnostic(
              diagnostics,
              "MTH203",
              "include alias `\{include_name}` refers to both `\{previous}` and `\{target}`",
              span,
            )
          _ => aliases[include_name] = target
        }
      }
      _ => ()
    }
  }
  aliases
}

///|
fn is_schema_type(definition : Definition) -> Bool {
  match definition {
    Typedef(..) | Enum(..) | Struct(..) | Union(..) | Exception(..) => true
    Const(..) | Service(..) => false
  }
}

///|
fn validate_qualified_reference(
  name : String,
  span : Span,
  aliases : Map[String, String],
  documents : ArrayView[Schema],
  diagnostics : Array[Diagnostic],
  service? : Bool = false,
) -> Unit {
  guard name.split_once(".") is Some((alias_view, symbol_view)) else { return }
  let include_name = alias_view.to_owned()
  let symbol = symbol_view.to_owned()
  guard aliases.get(include_name) is Some(target) else {
    push_workspace_diagnostic(
      diagnostics,
      "MTH204",
      "qualified reference `\{name}` uses unknown include alias `\{include_name}`",
      span,
    )
    return
  }
  guard find_document(documents, target) is Some(target_schema) else { return }
  guard find_definition(target_schema, symbol) is Some(definition) else {
    push_workspace_diagnostic(
      diagnostics,
      "MTH205",
      "included schema `\{target}` has no definition `\{symbol}`",
      span,
    )
    return
  }
  let valid = if service {
    definition is Service(..)
  } else {
    is_schema_type(definition)
  }
  if !valid {
    push_workspace_diagnostic(
      diagnostics,
      "MTH206",
      if service {
        "qualified service `\{name}` does not name a service"
      } else {
        "qualified type `\{name}` does not name a Thrift type"
      },
      span,
    )
  }
}

///|
fn validate_workspace_type(
  ty : TypeRef,
  span : Span,
  aliases : Map[String, String],
  documents : ArrayView[Schema],
  diagnostics : Array[Diagnostic],
) -> Unit {
  ty.walk_named(name => {
    if name.contains(".") {
      validate_qualified_reference(name, span, aliases, documents, diagnostics)
    }
  })
}

///|
fn validate_workspace_fields(
  fields : ArrayView[Field],
  aliases : Map[String, String],
  documents : ArrayView[Schema],
  diagnostics : Array[Diagnostic],
) -> Unit {
  for field in fields {
    validate_workspace_type(
      field.ty,
      field.span,
      aliases,
      documents,
      diagnostics,
    )
  }
}

///|
fn definition_reference(
  schema : Schema,
  name : String,
  documents : ArrayView[Schema],
) -> (Schema, Definition)? {
  match name.split_once(".") {
    None =>
      find_definition(schema, name).map(definition => (schema, definition))
    Some((include_view, symbol_view)) => {
      let include_name = include_view.to_owned()
      let symbol = symbol_view.to_owned()
      for header in schema.headers {
        match header {
          Include(path~, ..) if include_alias(path) == include_name => {
            let target = resolve_include_path(schema.source, path)
            guard find_document(documents, target) is Some(target_schema) else {
              return None
            }
            return find_definition(target_schema, symbol).map(definition => {
              (target_schema, definition)
            })
          }
          _ => ()
        }
      }
      None
    }
  }
}

///|
fn definition_key(schema : Schema, definition : Definition) -> String {
  "\{schema.source}#\{definition.name()}"
}

///|
fn check_typedef_cycle_from(
  schema : Schema,
  definition : Definition,
  documents : ArrayView[Schema],
  active : Array[String],
  diagnostics : Array[Diagnostic],
  reported : Array[String],
) -> Bool {
  guard definition is Typedef(target~, span~, ..) else { return false }
  let key = definition_key(schema, definition)
  if active.contains(key) {
    if !reported.contains(key) {
      let chain = active.copy()
      chain.push(key)
      push_workspace_diagnostic(
        diagnostics,
        "MTH207",
        "typedef cycle detected: \{chain.join(" -> ")}",
        span,
      )
      reported.push(key)
    }
    return true
  }
  active.push(key)
  let mut found = false
  target.walk_named(name => {
    if !found {
      match definition_reference(schema, name, documents) {
        Some((target_schema, target_definition)) if target_definition
          is Typedef(..) =>
          found = check_typedef_cycle_from(
            target_schema, target_definition, documents, active, diagnostics, reported,
          )
        _ => ()
      }
    }
  })
  ignore(active.pop())
  found
}

///|
fn check_service_cycle_from(
  schema : Schema,
  definition : Definition,
  documents : ArrayView[Schema],
  active : Array[String],
  diagnostics : Array[Diagnostic],
  reported : Array[String],
) -> Bool {
  guard definition is Service(extends~, span~, ..) else { return false }
  let key = definition_key(schema, definition)
  if active.contains(key) {
    if !reported.contains(key) {
      let chain = active.copy()
      chain.push(key)
      push_workspace_diagnostic(
        diagnostics,
        "MTH208",
        "service inheritance cycle detected: \{chain.join(" -> ")}",
        span,
      )
      reported.push(key)
    }
    return true
  }
  active.push(key)
  let found = match extends {
    None => false
    Some(base) =>
      match definition_reference(schema, base, documents) {
        Some((base_schema, base_definition)) if base_definition is Service(..) =>
          check_service_cycle_from(
            base_schema, base_definition, documents, active, diagnostics, reported,
          )
        _ => false
      }
  }
  ignore(active.pop())
  found
}

///|
fn validate_workspace_cycles(
  documents : ArrayView[Schema],
  diagnostics : Array[Diagnostic],
) -> Unit {
  let typedef_reports : Array[String] = []
  let service_reports : Array[String] = []
  for schema in documents {
    for definition in schema.definitions {
      match definition {
        Typedef(..) =>
          ignore(
            check_typedef_cycle_from(
              schema,
              definition,
              documents,
              [],
              diagnostics,
              typedef_reports,
            ),
          )
        Service(..) =>
          ignore(
            check_service_cycle_from(
              schema,
              definition,
              documents,
              [],
              diagnostics,
              service_reports,
            ),
          )
        _ => ()
      }
    }
  }
}

///|
fn validate_workspace_schema(
  schema : Schema,
  documents : ArrayView[Schema],
  diagnostics : Array[Diagnostic],
) -> Unit {
  diagnostics.append(check_schema(schema))
  let aliases = direct_include_aliases(schema, diagnostics)
  for definition in schema.definitions {
    match definition {
      Const(ty~, span~, ..) | Typedef(target=ty, span~, ..) =>
        validate_workspace_type(ty, span, aliases, documents, diagnostics)
      Enum(..) => ()
      Struct(fields~, ..) | Union(fields~, ..) | Exception(fields~, ..) =>
        validate_workspace_fields(fields, aliases, documents, diagnostics)
      Service(extends~, functions~, span~, ..) => {
        if extends is Some(base) && base.contains(".") {
          validate_qualified_reference(
            base,
            span,
            aliases,
            documents,
            diagnostics,
            service=true,
          )
        }
        for function in functions {
          validate_workspace_type(
            function.return_type,
            function.span,
            aliases,
            documents,
            diagnostics,
          )
          validate_workspace_fields(
            function.arguments,
            aliases,
            documents,
            diagnostics,
          )
          validate_workspace_fields(
            function.throws,
            aliases,
            documents,
            diagnostics,
          )
        }
      }
    }
  }
}

///|
/// Loads, parses, and validates a complete Thrift include graph.
///
/// Paths passed to `loader` use `/`, contain no `.` segments, and resolve `..`
/// relative to the including document. Missing sources and link failures are
/// returned as diagnostics; lexical and syntactic failures raise `IdlError`.
pub fn compile_workspace(
  root : String,
  loader : SourceLoader,
) -> (SchemaWorkspace, Array[Diagnostic]) raise IdlError {
  let normalized_root = normalize_schema_path(root)
  let documents : Array[Schema] = []
  let diagnostics : Array[Diagnostic] = []
  load_workspace_document(
    normalized_root,
    Span::synthetic(source=normalized_root),
    loader,
    documents,
    [],
    diagnostics,
  )
  for schema in documents {
    validate_workspace_schema(schema, documents, diagnostics)
  }
  validate_workspace_cycles(documents, diagnostics)
  ({ root: normalized_root, documents, }, diagnostics)
}
