///|
priv struct Lexer {
  input : String
  source : String
  mut offset : Int
  mut line : Int
  mut column : Int
}

///|
fn Lexer::span(self : Lexer, start : Int, line : Int, column : Int) -> Span {
  { source: self.source, start, end: self.offset, line, column, }
}

///|
fn Lexer::current(self : Lexer) -> Char? {
  self.input.get_char(self.offset)
}

///|
fn Lexer::peek(self : Lexer, distance : Int) -> Char? {
  self.input.get_char(self.offset + distance)
}

///|
fn Lexer::advance(self : Lexer) -> Char? {
  match self.current() {
    None => None
    Some(char) => {
      self.offset += char.utf16_len()
      if char == '\n' {
        self.line += 1
        self.column = 1
      } else {
        self.column += 1
      }
      Some(char)
    }
  }
}

///|
fn is_identifier_start(char : Char) -> Bool {
  char.is_ascii_alphabetic() || char == '_'
}

///|
fn is_identifier_continue(char : Char) -> Bool {
  is_identifier_start(char) || char.is_ascii_digit() || char == '.'
}

///|
fn Lexer::skip_line_comment(self : Lexer) -> Unit {
  while self.current() is Some(char) && char != '\n' {
    ignore(self.advance())
  }
}

///|
fn Lexer::skip_block_comment(self : Lexer, start : Span) -> Unit raise IdlError {
  ignore(self.advance())
  ignore(self.advance())
  while self.current() is Some(char) {
    if char == '*' && self.peek(1) == Some('/') {
      ignore(self.advance())
      ignore(self.advance())
      return
    }
    ignore(self.advance())
  }
  raise UnterminatedComment(start)
}

///|
fn Lexer::skip_trivia(self : Lexer) -> Unit raise IdlError {
  while self.current() is Some(char) {
    if char.is_ascii_whitespace() {
      ignore(self.advance())
    } else if char == '#' {
      self.skip_line_comment()
    } else if char == '/' &&
      self.peek(1) == Some('/') &&
      self.peek(2) == Some('/') {
      return
    } else if char == '/' &&
      self.peek(1) == Some('*') &&
      self.peek(2) == Some('*') {
      return
    } else if char == '/' && self.peek(1) == Some('/') {
      self.skip_line_comment()
    } else if char == '/' && self.peek(1) == Some('*') {
      let start = {
        source: self.source,
        start: self.offset,
        end: self.offset,
        line: self.line,
        column: self.column,
      }
      self.skip_block_comment(start)
    } else {
      return
    }
  }
}

///|
fn Lexer::line_doc_comment(self : Lexer) -> Token {
  let start = self.offset
  let line = self.line
  let column = self.column
  ignore(self.advance())
  ignore(self.advance())
  ignore(self.advance())
  let value = StringBuilder()
  while self.current() is Some(char) && char != '\n' {
    value.write_char(char)
    ignore(self.advance())
  }
  {
    kind: DocComment(value.to_string().trim().to_owned()),
    span: self.span(start, line, column),
  }
}

///|
fn normalize_block_doc(value : String) -> String {
  value
  .split("\n")
  .map(line => {
    let trimmed = line.trim()
    trimmed.strip_prefix("*").unwrap_or(trimmed).trim().to_owned()
  })
  .join("\n")
  .trim()
  .to_owned()
}

///|
fn Lexer::block_doc_comment(self : Lexer) -> Token raise IdlError {
  let start = self.offset
  let line = self.line
  let column = self.column
  ignore(self.advance())
  ignore(self.advance())
  ignore(self.advance())
  let value = StringBuilder()
  while self.current() is Some(char) {
    if char == '*' && self.peek(1) == Some('/') {
      ignore(self.advance())
      ignore(self.advance())
      return {
        kind: DocComment(normalize_block_doc(value.to_string())),
        span: self.span(start, line, column),
      }
    }
    value.write_char(char)
    ignore(self.advance())
  }
  raise UnterminatedComment(self.span(start, line, column))
}

///|
fn Lexer::identifier(self : Lexer) -> Token {
  let start = self.offset
  let line = self.line
  let column = self.column
  while self.current() is Some(char) && is_identifier_continue(char) {
    ignore(self.advance())
  }
  let value = self.input.unsafe_substring(start~, end=self.offset)
  { kind: Identifier(value), span: self.span(start, line, column), }
}

///|
fn Lexer::number(self : Lexer) -> Token raise IdlError {
  let start = self.offset
  let line = self.line
  let column = self.column
  if self.current() == Some('-') {
    ignore(self.advance())
  }
  let mut floating = false
  if self.current() == Some('0') &&
    (self.peek(1) == Some('x') || self.peek(1) == Some('X')) {
    ignore(self.advance())
    ignore(self.advance())
    while self.current() is Some(char) && char.is_ascii_hexdigit() {
      ignore(self.advance())
    }
  } else {
    while self.current() is Some(char) && char.is_ascii_digit() {
      ignore(self.advance())
    }
    if self.current() == Some('.') &&
      self.peek(1) is Some(next) &&
      next.is_ascii_digit() {
      floating = true
      ignore(self.advance())
      while self.current() is Some(char) && char.is_ascii_digit() {
        ignore(self.advance())
      }
    }
    if self.current() is Some('e' | 'E') {
      floating = true
      ignore(self.advance())
      if self.current() is Some('+' | '-') {
        ignore(self.advance())
      }
      while self.current() is Some(char) && char.is_ascii_digit() {
        ignore(self.advance())
      }
    }
  }
  let text = self.input.unsafe_substring(start~, end=self.offset)
  if floating {
    let value : Double = @str.from_str(text) catch {
      _ => raise InvalidInteger(text, self.span(start, line, column))
    }
    { kind: FloatLiteral(value), span: self.span(start, line, column), }
  } else {
    let value : Int64 = @str.from_str(text) catch {
      _ => raise InvalidInteger(text, self.span(start, line, column))
    }
    { kind: IntegerLiteral(value), span: self.span(start, line, column), }
  }
}

///|
fn Lexer::string_literal(self : Lexer) -> Token raise IdlError {
  let start = self.offset
  let line = self.line
  let column = self.column
  let quote = self.advance().unwrap()
  let value = StringBuilder()
  while self.current() is Some(char) {
    if char == quote {
      ignore(self.advance())
      return {
        kind: StringLiteral(value.to_string()),
        span: self.span(start, line, column),
      }
    }
    if char == '\n' || char == '\r' {
      raise UnterminatedString(self.span(start, line, column))
    }
    ignore(self.advance())
    if char == '\\' {
      let escape_span = self.span(self.offset - 1, self.line, self.column - 1)
      match self.advance() {
        Some('n') => value.write_char('\n')
        Some('r') => value.write_char('\r')
        Some('t') => value.write_char('\t')
        Some('\\') => value.write_char('\\')
        Some('\'') => value.write_char('\'')
        Some('"') => value.write_char('"')
        Some(other) => raise InvalidEscape(other, escape_span)
        None => raise UnterminatedString(self.span(start, line, column))
      }
    } else {
      value.write_char(char)
    }
  }
  raise UnterminatedString(self.span(start, line, column))
}

///|
fn is_symbol(char : Char) -> Bool {
  match char {
    '{'
    | '}'
    | '['
    | ']'
    | '('
    | ')'
    | '<'
    | '>'
    | ':'
    | ';'
    | ','
    | '='
    | '*'
    | '+' => true
    _ => false
  }
}

///|
fn Lexer::next_token(self : Lexer) -> Token raise IdlError {
  self.skip_trivia()
  let start = self.offset
  let line = self.line
  let column = self.column
  match self.current() {
    None =>
      {
        kind: End,
        span: { source: self.source, start, end: start, line, column, },
      }
    Some('/') if self.peek(1) == Some('/') && self.peek(2) == Some('/') =>
      self.line_doc_comment()
    Some('/') if self.peek(1) == Some('*') && self.peek(2) == Some('*') =>
      self.block_doc_comment()
    Some(char) if is_identifier_start(char) => self.identifier()
    Some('-') if self.peek(1) is Some(next) && next.is_ascii_digit() =>
      self.number()
    Some(char) if char.is_ascii_digit() => self.number()
    Some('\'' | '"') => self.string_literal()
    Some(char) if is_symbol(char) => {
      ignore(self.advance())
      { kind: Symbol(char), span: self.span(start, line, column), }
    }
    Some(char) => {
      ignore(self.advance())
      raise UnexpectedCharacter(char, self.span(start, line, column))
    }
  }
}

///|
/// Tokenizes one Thrift IDL document without accessing the file system.
pub fn lex(
  input : String,
  source? : String = "<memory>",
) -> Array[Token] raise IdlError {
  let lexer = { input, source, offset: 0, line: 1, column: 1, }
  let tokens : Array[Token] = []
  while true {
    let token = lexer.next_token()
    let done = token.kind is End
    tokens.push(token)
    if done {
      break
    }
  }
  tokens
}
