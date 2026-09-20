///|
/// Compatibility classification for schema evolution.
pub(all) enum ChangeKind {
  Compatible
  Warning
  Breaking
} derive(Debug, Eq, ToJson)

///|
/// One stable schema-evolution finding.
pub(all) struct SchemaChange {
  code : String
  kind : ChangeKind
  path : String
  message : String
} derive(Debug, Eq, ToJson)

///|
fn change(
  code : String,
  kind : ChangeKind,
  path : String,
  message : String,
) -> SchemaChange {
  { code, kind, path, message, }
}

///|
fn find_definition(schema : Schema, name : String) -> Definition? {
  for definition in schema.definitions {
    if definition.name() == name {
      return Some(definition)
    }
  }
  None
}

///|
fn find_field(fields : ArrayView[Field], id : Int) -> Field? {
  for field in fields {
    if field.id == id {
      return Some(field)
    }
  }
  None
}

///|
fn find_enum_value(members : ArrayView[EnumMember], value : Int) -> EnumMember? {
  for enum_member in members {
    if enum_member.value == value {
      return Some(enum_member)
    }
  }
  None
}

///|
fn find_function(
  functions : ArrayView[FunctionDef],
  name : String,
) -> FunctionDef? {
  for function in functions {
    if function.name == name {
      return Some(function)
    }
  }
  None
}

///|
fn TypeRef::wire_equal(self : TypeRef, other : TypeRef) -> Bool {
  match (self, other) {
    (CppType(inner, _), right) => inner.wire_equal(right)
    (left, CppType(inner, _)) => left.wire_equal(inner)
    (Base(left), Base(right)) => left == right
    (Named(left), Named(right)) => left == right
    (List(left), List(right)) | (Set(left), Set(right)) =>
      left.wire_equal(right)
    (Map(left_key, left_value), Map(right_key, right_value)) =>
      left_key.wire_equal(right_key) && left_value.wire_equal(right_value)
    _ => false
  }
}

///|
fn compare_fields(
  path : String,
  before_fields : ArrayView[Field],
  after_fields : ArrayView[Field],
  changes : Array[SchemaChange],
) -> Unit {
  for before_field in before_fields {
    let field_path = "\{path}.\{before_field.name}#\{before_field.id}"
    match find_field(after_fields, before_field.id) {
      None => {
        let kind = if before_field.requiredness is Required {
          Breaking
        } else {
          Warning
        }
        changes.push(
          change(
            "MTHC103",
            kind,
            field_path,
            "field id \{before_field.id} was removed",
          ),
        )
      }
      Some(after_field) => {
        if !before_field.ty.wire_equal(after_field.ty) {
          changes.push(
            change(
              "MTHC104",
              Breaking,
              field_path,
              "field type changed from \{Repr(before_field.ty)} to \{Repr(after_field.ty)}",
            ),
          )
        }
        if before_field.name != after_field.name {
          changes.push(
            change(
              "MTHC105",
              Warning,
              field_path,
              "field name changed to `\{after_field.name}` while retaining its id",
            ),
          )
        }
        if !(before_field.requiredness is Required) &&
          after_field.requiredness is Required {
          changes.push(
            change("MTHC106", Breaking, field_path, "field became required"),
          )
        }
      }
    }
  }
  for after_field in after_fields {
    if find_field(before_fields, after_field.id) is None {
      let field_path = "\{path}.\{after_field.name}#\{after_field.id}"
      let kind = if after_field.requiredness is Required {
        Breaking
      } else {
        Compatible
      }
      changes.push(
        change(
          "MTHC107",
          kind,
          field_path,
          if kind is Breaking {
            "new required field cannot be read from older payloads"
          } else {
            "optional field was added"
          },
        ),
      )
    }
  }
}

///|
fn compare_enums(
  path : String,
  before_members : ArrayView[EnumMember],
  after_members : ArrayView[EnumMember],
  changes : Array[SchemaChange],
) -> Unit {
  for before_member in before_members {
    match find_enum_value(after_members, before_member.value) {
      None =>
        changes.push(
          change(
            "MTHC108",
            Breaking,
            "\{path}.\{before_member.name}",
            "enum value \{before_member.value} was removed",
          ),
        )
      Some(after_member) if before_member.name != after_member.name =>
        changes.push(
          change(
            "MTHC109",
            Warning,
            "\{path}.\{before_member.name}",
            "enum value \{before_member.value} was renamed to `\{after_member.name}`",
          ),
        )
      _ => ()
    }
  }
  for after_member in after_members {
    if find_enum_value(before_members, after_member.value) is None {
      changes.push(
        change(
          "MTHC110",
          Compatible,
          "\{path}.\{after_member.name}",
          "enum value \{after_member.value} was added",
        ),
      )
    }
  }
}

///|
fn compare_functions(
  path : String,
  before_functions : ArrayView[FunctionDef],
  after_functions : ArrayView[FunctionDef],
  changes : Array[SchemaChange],
) -> Unit {
  for before_function in before_functions {
    let function_path = "\{path}.\{before_function.name}"
    match find_function(after_functions, before_function.name) {
      None =>
        changes.push(
          change(
            "MTHC111",
            Breaking,
            function_path,
            "service function was removed",
          ),
        )
      Some(after_function) => {
        if !before_function.return_type.wire_equal(after_function.return_type) ||
          before_function.oneway != after_function.oneway {
          changes.push(
            change(
              "MTHC112",
              Breaking,
              function_path,
              "return type or oneway behavior changed",
            ),
          )
        }
        compare_fields(
          "\{function_path}.args",
          before_function.arguments,
          after_function.arguments,
          changes,
        )
        compare_fields(
          "\{function_path}.throws",
          before_function.throws,
          after_function.throws,
          changes,
        )
      }
    }
  }
  for after_function in after_functions {
    if find_function(before_functions, after_function.name) is None {
      changes.push(
        change(
          "MTHC113",
          Compatible,
          "\{path}.\{after_function.name}",
          "service function was added",
        ),
      )
    }
  }
}

///|
fn compare_definition(
  before_definition : Definition,
  after_definition : Definition,
  changes : Array[SchemaChange],
) -> Unit {
  let path = before_definition.name()
  if before_definition.kind() != after_definition.kind() {
    changes.push(
      change(
        "MTHC102",
        Breaking,
        path,
        "definition kind changed from \{before_definition.kind()} to \{after_definition.kind()}",
      ),
    )
    return
  }
  match (before_definition, after_definition) {
    (Typedef(target=before_target, ..), Typedef(target=after_target, ..)) =>
      if !before_target.wire_equal(after_target) {
        changes.push(
          change("MTHC114", Breaking, path, "typedef target changed"),
        )
      }
    (Enum(members=before_members, ..), Enum(members=after_members, ..)) =>
      compare_enums(path, before_members, after_members, changes)
    (
      Struct(fields=before_fields, ..)
      | Union(fields=before_fields, ..)
      | Exception(fields=before_fields, ..),
      Struct(fields=after_fields, ..)
      | Union(fields=after_fields, ..)
      | Exception(fields=after_fields, ..),
    ) => compare_fields(path, before_fields, after_fields, changes)
    (
      Service(extends=before_extends, functions=before_functions, ..),
      Service(extends=after_extends, functions=after_functions, ..),
    ) => {
      if before_extends != after_extends {
        changes.push(
          change("MTHC115", Breaking, path, "service inheritance changed"),
        )
      }
      compare_functions(path, before_functions, after_functions, changes)
    }
    (
      Const(ty=before_type, value=before_value, ..),
      Const(ty=after_type, value=after_value, ..),
    ) =>
      if !before_type.wire_equal(after_type) || before_value != after_value {
        changes.push(
          change("MTHC116", Warning, path, "constant type or value changed"),
        )
      }
    _ => ()
  }
}

///|
/// Compares two checked schemas by stable field IDs, enum values, and service
/// method names. Results are ordered deterministically by the old schema first,
/// followed by additions from the new schema.
pub fn compare_schemas(before : Schema, after : Schema) -> Array[SchemaChange] {
  let changes : Array[SchemaChange] = []
  for before_definition in before.definitions {
    match find_definition(after, before_definition.name()) {
      None =>
        changes.push(
          change(
            "MTHC101",
            Breaking,
            before_definition.name(),
            "definition was removed",
          ),
        )
      Some(after_definition) =>
        compare_definition(before_definition, after_definition, changes)
    }
  }
  for after_definition in after.definitions {
    if find_definition(before, after_definition.name()) is None {
      changes.push(
        change(
          "MTHC117",
          Compatible,
          after_definition.name(),
          "definition was added",
        ),
      )
    }
  }
  changes
}

///|
pub fn has_breaking_changes(changes : ArrayView[SchemaChange]) -> Bool {
  changes.any(item => item.kind is Breaking)
}

///|
pub fn SchemaChange::to_text(self : SchemaChange) -> String {
  let level = match self.kind {
    Compatible => "compatible"
    Warning => "warning"
    Breaking => "breaking"
  }
  "\{level}[\{self.code}] \{self.path}: \{self.message}"
}
