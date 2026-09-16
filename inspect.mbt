///|
pub fn Diagnostic::to_text(self : Diagnostic) -> String {
  let level = match self.severity {
    Error => "error"
    Warning => "warning"
  }
  "\{self.span.source}:\{self.span.line}:\{self.span.column}: \{level}[\{self.code}]: \{self.message}"
}

///|
pub fn has_errors(diagnostics : ArrayView[Diagnostic]) -> Bool {
  diagnostics.any(item => item.severity is Error)
}

///|
pub fn Definition::kind(self : Definition) -> String {
  match self {
    Const(..) => "const"
    Typedef(..) => "typedef"
    Enum(..) => "enum"
    Struct(..) => "struct"
    Union(..) => "union"
    Exception(..) => "exception"
    Service(..) => "service"
  }
}

///|
/// Produces a compact human-readable schema outline for CLIs and build logs.
pub fn Schema::to_outline(self : Schema) -> String {
  let output = StringBuilder()
  output.write_string("schema \{self.source}\n")
  output.write_string("  headers: \{self.headers.length()}\n")
  output.write_string("  definitions: \{self.definitions.length()}\n")
  for definition in self.definitions {
    output.write_string("    \{definition.kind()} \{definition.name()}\n")
  }
  output.to_string()
}
