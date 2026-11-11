///|
/// Token kinds emitted by the Thrift IDL lexer.
#derive(Debug, Eq)
pub(all) enum TokenKind {
  Identifier(String)
  StringLiteral(String)
  IntegerLiteral(Int64)
  FloatLiteral(Double)
  DocComment(String)
  Symbol(Char)
  End
}

///|
/// One lexical token and its source location.
#derive(Debug, Eq)
pub(all) struct Token {
  kind : TokenKind
  span : Span
}

///|
pub fn Token::describe(self : Token) -> String {
  match self.kind {
    Identifier(value) => "identifier `\{value}`"
    StringLiteral(_) => "string literal"
    IntegerLiteral(value) => "integer `\{value}`"
    FloatLiteral(value) => "floating-point number `\{value}`"
    DocComment(_) => "documentation comment"
    Symbol(value) => "`\{value}`"
    End => "end of input"
  }
}
