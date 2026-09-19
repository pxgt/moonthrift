///|
fn Definition::span(self : Definition) -> Span {
  match self {
    Const(span~, ..)
    | Typedef(span~, ..)
    | Enum(span~, ..)
    | Struct(span~, ..)
    | Union(span~, ..)
    | Exception(span~, ..)
    | Service(span~, ..) => span
  }
}

///|
fn diagnostic(
  code : String,
  message : String,
  span : Span,
  severity? : Severity = Error,
) -> Diagnostic {
  { code, severity, message, span, }
}

///|
fn definition_names(schema : Schema) -> Array[String] {
  schema.definitions.map(definition => definition.name())
}

///|
fn contains_name(names : ArrayView[String], name : String) -> Bool {
  names.any(item => item == name)
}

///|
fn TypeRef::walk_named(self : TypeRef, visit : (String) -> Unit) -> Unit {
  match self {
    Named(name) => visit(name)
    List(element) | Set(element) => element.walk_named(visit)
    Map(key, value) => {
      key.walk_named(visit)
      value.walk_named(visit)
    }
    CppType(inner, _) => inner.walk_named(visit)
    Base(_) => ()
  }
}

///|
fn validate_type(
  ty : TypeRef,
  names : ArrayView[String],
  span : Span,
  diagnostics : Array[Diagnostic],
  allow_void? : Bool = false,
) -> Unit {
  match ty {
    Base(Void) if !allow_void =>
      diagnostics.push(
        diagnostic(
          "MTH103", "void is only valid as a service return type", span,
        ),
      )
    _ =>
      ty.walk_named(name => {
        if !contains_name(names, name) && !name.contains(".") {
          diagnostics.push(
            diagnostic("MTH102", "unresolved type `\{name}`", span),
          )
        }
      })
  }
}

///|
fn validate_field_set(
  fields : ArrayView[Field],
  names : ArrayView[String],
  diagnostics : Array[Diagnostic],
  union? : Bool = false,
) -> Unit {
  for index, field in fields {
    validate_type(field.ty, names, field.span, diagnostics)
    if field.id == 0 {
      diagnostics.push(
        diagnostic(
          "MTH106",
          "field `\{field.name}` uses reserved id 0",
          field.span,
        ),
      )
    }
    if union && field.requiredness is Required {
      diagnostics.push(
        diagnostic(
          "MTH107",
          "union field `\{field.name}` cannot be required",
          field.span,
        ),
      )
    }
    for previous in fields[:index] {
      if previous.id == field.id {
        diagnostics.push(
          diagnostic("MTH104", "duplicate field id \{field.id}", field.span),
        )
      }
      if previous.name == field.name {
        diagnostics.push(
          diagnostic(
            "MTH105",
            "duplicate field name `\{field.name}`",
            field.span,
          ),
        )
      }
    }
  }
}

///|
fn is_service(schema : Schema, name : String) -> Bool {
  schema.definitions.any(definition => {
    definition is Service(name=actual, ..) && actual == name
  })
}

///|
fn validate_service(
  schema : Schema,
  service_name : String,
  extends : String?,
  functions : ArrayView[FunctionDef],
  names : ArrayView[String],
  span : Span,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if extends is Some(base) && !base.contains(".") && !is_service(schema, base) {
    diagnostics.push(
      diagnostic(
        "MTH111",
        "service `\{service_name}` extends unknown service `\{base}`",
        span,
      ),
    )
  }
  for index, function in functions {
    validate_type(
      function.return_type,
      names,
      function.span,
      diagnostics,
      allow_void=true,
    )
    validate_field_set(function.arguments, names, diagnostics)
    validate_field_set(function.throws, names, diagnostics)
    if function.oneway {
      if function.return_type != Base(Void) {
        diagnostics.push(
          diagnostic(
            "MTH109",
            "oneway function `\{function.name}` must return void",
            function.span,
          ),
        )
      }
      if function.throws.length() > 0 {
        diagnostics.push(
          diagnostic(
            "MTH110",
            "oneway function `\{function.name}` cannot declare throws",
            function.span,
          ),
        )
      }
    }
    for previous in functions[:index] {
      if previous.name == function.name {
        diagnostics.push(
          diagnostic(
            "MTH108",
            "duplicate service function `\{function.name}`",
            function.span,
          ),
        )
      }
    }
  }
}

///|
fn validate_enum(
  members : ArrayView[EnumMember],
  diagnostics : Array[Diagnostic],
) -> Unit {
  for index, current_member in members {
    for previous in members[:index] {
      if previous.name == current_member.name {
        diagnostics.push(
          diagnostic(
            "MTH112",
            "duplicate enum member `\{current_member.name}`",
            current_member.span,
          ),
        )
      }
      if previous.value == current_member.value {
        diagnostics.push(
          diagnostic(
            "MTH113",
            "enum value \{current_member.value} is assigned more than once",
            current_member.span,
            severity=Warning,
          ),
        )
      }
    }
  }
}

///|
/// Performs deterministic semantic checks without file-system access.
///
/// Qualified names are accepted as references into an included schema. The
/// caller can resolve and check include graphs separately.
pub fn check_schema(schema : Schema) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  let names = definition_names(schema)
  for index, definition in schema.definitions {
    for previous in schema.definitions[:index] {
      if previous.name() == definition.name() {
        diagnostics.push(
          diagnostic(
            "MTH101",
            "duplicate definition `\{definition.name()}`",
            definition.span(),
          ),
        )
      }
    }
    match definition {
      Const(ty~, span~, ..) => validate_type(ty, names, span, diagnostics)
      Typedef(target~, span~, ..) => {
        validate_type(target, names, span, diagnostics)
        if target == Named(definition.name()) {
          diagnostics.push(
            diagnostic("MTH114", "typedef cannot directly name itself", span),
          )
        }
      }
      Enum(members~, ..) => validate_enum(members, diagnostics)
      Struct(fields~, ..) | Exception(fields~, ..) =>
        validate_field_set(fields, names, diagnostics)
      Union(fields~, ..) =>
        validate_field_set(fields, names, diagnostics, union=true)
      Service(name~, extends~, functions~, span~, ..) =>
        validate_service(
          schema, name, extends, functions, names, span, diagnostics,
        )
    }
  }
  diagnostics
}

///|
/// Parses and validates a document in one call.
pub fn compile_idl(
  input : String,
  source? : String = "<memory>",
) -> (Schema, Array[Diagnostic]) raise IdlError {
  let schema = parse_idl(input, source~)
  (schema, check_schema(schema))
}
