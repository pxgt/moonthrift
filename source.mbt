///|
/// A half-open source range in a Thrift document.
pub(all) struct Span {
  source : String
  start : Int
  end : Int
  line : Int
  column : Int
} derive(Debug, Eq, ToJson)

///|
/// Creates a synthetic span for programmatically constructed declarations.
pub fn Span::synthetic(source? : String = "<generated>") -> Span {
  { source, start: 0, end: 0, line: 1, column: 1, }
}

///|
/// Severity of a schema diagnostic.
pub(all) enum Severity {
  Error
  Warning
} derive(Debug, Eq, ToJson)

///|
/// A stable, source-aware diagnostic produced by parsing or validation.
pub(all) struct Diagnostic {
  code : String
  severity : Severity
  message : String
  span : Span
} derive(Debug, Eq, ToJson)

///|
/// A fatal lexical or syntactic error.
pub(all) suberror IdlError {
  UnexpectedCharacter(Char, Span)
  UnterminatedString(Span)
  UnterminatedComment(Span)
  InvalidEscape(Char, Span)
  InvalidInteger(String, Span)
  UnexpectedToken(String, Span)
  UnexpectedEnd(Span)
} derive(Debug, Eq)
