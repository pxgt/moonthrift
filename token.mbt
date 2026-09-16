///|
/// Token kinds emitted by the Thrift IDL lexer.
pub(all) enum TokenKind {
  Identifier(String)
  StringLiteral(String)
  IntegerLiteral(Int64)
  Symbol(Char)
  End
} derive(Debug, Eq)

///|
/// One lexical token and its source location.
pub(all) struct Token {
  kind : TokenKind
  span : Span
} derive(Debug, Eq)

///|
pub fn Token::describe(self : Token) -> String {
  match self.kind {
    Identifier(value) => "identifier `\{value}`"
    StringLiteral(_) => "string literal"
    IntegerLiteral(value) => "integer `\{value}`"
    Symbol(value) => "`\{value}`"
    End => "end of input"
  }
}
