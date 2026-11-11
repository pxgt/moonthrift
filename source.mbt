///|
/// A half-open source range in a Thrift document.
#derive(Debug, Eq, ToJson)
pub(all) struct Span {
  source : String
  start : Int32
  end : Int32
  line : Int32
  column : Int32
}

///|
/// Creates a synthetic span for programmatically constructed declarations.
pub fn Span::synthetic(source~ : String = "<generated>") -> Span {
  { source, start: 0, end: 0, line: 1, column: 1, }
}

///|
/// Severity of a schema diagnostic.
#derive(Debug, Eq, ToJson)
pub(all) enum Severity {
  Error
  Warning
}

///|
/// A stable, source-aware diagnostic produced by parsing or validation.
#derive(Debug, Eq, ToJson)
pub(all) struct Diagnostic {
  code : String
  severity : Severity
  message : String
  span : Span
}

///|
/// A fatal lexical or syntactic error.
#derive(Debug, Eq)
pub(all) suberror IdlError {
  UnexpectedCharacter(Char, Span)
  UnterminatedString(Span)
  UnterminatedComment(Span)
  InvalidEscape(Char, Span)
  InvalidInteger(String, Span)
  UnexpectedToken(String, Span)
  UnexpectedEnd(Span)
}
