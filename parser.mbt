///|
priv struct Parser {
  tokens : Array[Token]
  mut index : Int
}

///|
fn Parser::current(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.current()
  if !(token.kind is End) {
    self.index += 1
  }
  token
}

///|
fn Parser::unexpected(self : Parser) -> Unit raise IdlError {
  let token = self.current()
  if token.kind is End {
    raise UnexpectedEnd(token.span)
  }
  raise UnexpectedToken(token.describe(), token.span)
}

///|
fn Parser::eat_symbol(self : Parser, expected : Char) -> Bool {
  if self.current().kind is Symbol(actual) && actual == expected {
    ignore(self.advance())
    true
  } else {
    false
  }
}

///|
fn Parser::expect_symbol(self : Parser, expected : Char) -> Unit raise IdlError {
  if !self.eat_symbol(expected) {
    self.unexpected()
  }
}

///|
fn Parser::is_word(self : Parser, expected : String) -> Bool {
  self.current().kind is Identifier(actual) && actual == expected
}

///|
fn Parser::eat_word(self : Parser, expected : String) -> Bool {
  if self.is_word(expected) {
    ignore(self.advance())
    true
  } else {
    false
  }
}

///|
fn Parser::expect_name(self : Parser) -> (String, Span) raise IdlError {
  match self.advance() {
    { kind: Identifier(value), span, } => (value, span)
    token => raise UnexpectedToken(token.describe(), token.span)
  }
}

///|
fn Parser::expect_string(self : Parser) -> (String, Span) raise IdlError {
  match self.advance() {
    { kind: StringLiteral(value), span, } => (value, span)
    token => raise UnexpectedToken(token.describe(), token.span)
  }
}

///|
fn Parser::separator(self : Parser) -> Unit {
  if !self.eat_symbol(',') {
    ignore(self.eat_symbol(';'))
  }
}

///|
fn Parser::parse_type(self : Parser) -> TypeRef raise IdlError {
  let (name, _) = self.expect_name()
  match name {
    "bool" => Base(Bool)
    "byte" | "i8" => Base(Byte)
    "i16" => Base(I16)
    "i32" => Base(I32)
    "i64" => Base(I64)
    "double" => Base(Double)
    "string" => Base(String)
    "binary" => Base(Binary)
    "void" => Base(Void)
    "list" => {
      self.expect_symbol('<')
      let element = self.parse_type()
      self.expect_symbol('>')
      List(element)
    }
    "set" => {
      self.expect_symbol('<')
      let element = self.parse_type()
      self.expect_symbol('>')
      Set(element)
    }
    "map" => {
      self.expect_symbol('<')
      let key = self.parse_type()
      self.expect_symbol(',')
      let value = self.parse_type()
      self.expect_symbol('>')
      Map(key, value)
    }
    named => Named(named)
  }
}

///|
fn Parser::parse_const_value(self : Parser) -> ConstValue raise IdlError {
  match self.advance() {
    { kind: StringLiteral(value), .. } => StringValue(value)
    { kind: IntegerLiteral(value), .. } => IntegerValue(value)
    { kind: FloatLiteral(value), .. } => DoubleValue(value)
    { kind: Identifier("true"), .. } => BoolValue(true)
    { kind: Identifier("false"), .. } => BoolValue(false)
    { kind: Identifier(value), .. } => IdentifierValue(value)
    { kind: Symbol('['), .. } => {
      let values : Array[ConstValue] = []
      while !self.eat_symbol(']') {
        values.push(self.parse_const_value())
        self.separator()
      }
      ListValue(values)
    }
    { kind: Symbol('{'), .. } => {
      let entries : Array[(ConstValue, ConstValue)] = []
      while !self.eat_symbol('}') {
        let key = self.parse_const_value()
        if !self.eat_symbol(':') {
          self.expect_symbol('=')
        }
        let value = self.parse_const_value()
        entries.push((key, value))
        self.separator()
      }
      MapValue(entries)
    }
    token => raise UnexpectedToken(token.describe(), token.span)
  }
}

///|
fn Parser::parse_annotations(self : Parser) -> Array[Annotation] raise IdlError {
  let annotations : Array[Annotation] = []
  if !self.eat_symbol('(') {
    return annotations
  }
  while !self.eat_symbol(')') {
    let (key, _) = self.expect_name()
    let value = if self.eat_symbol('=') {
      match self.advance() {
        { kind: StringLiteral(value) | Identifier(value), .. } => Some(value)
        { kind: IntegerLiteral(value), .. } => Some(value.to_string())
        token => raise UnexpectedToken(token.describe(), token.span)
      }
    } else {
      None
    }
    annotations.push({ key, value, })
    self.separator()
  }
  annotations
}

///|
fn Parser::parse_field(self : Parser) -> Field raise IdlError {
  let id_token = self.advance()
  let id = match id_token.kind {
    IntegerLiteral(value) => value.to_int()
    _ => raise UnexpectedToken(id_token.describe(), id_token.span)
  }
  self.expect_symbol(':')
  let requiredness = if self.eat_word("required") {
    Required
  } else if self.eat_word("optional") {
    Optional
  } else {
    Default
  }
  let ty = self.parse_type()
  let (name, _) = self.expect_name()
  let default_value = if self.eat_symbol('=') {
    Some(self.parse_const_value())
  } else {
    None
  }
  let annotations = self.parse_annotations()
  self.separator()
  {
    id,
    requiredness,
    ty,
    name,
    default_value,
    annotations,
    span: id_token.span,
  }
}

///|
fn Parser::parse_fields(
  self : Parser,
  close : Char,
) -> Array[Field] raise IdlError {
  let fields : Array[Field] = []
  while !self.eat_symbol(close) {
    fields.push(self.parse_field())
  }
  fields
}

///|
fn Parser::parse_header(self : Parser) -> Header raise IdlError {
  let keyword = self.advance()
  match keyword.kind {
    Identifier("include") => {
      let (path, _) = self.expect_string()
      Include(path~, span=keyword.span)
    }
    Identifier("cpp_include") => {
      let (path, _) = self.expect_string()
      CppInclude(path~, span=keyword.span)
    }
    Identifier("namespace") => {
      let language = match self.advance() {
        { kind: Identifier(value), .. } => value
        { kind: Symbol('*'), .. } => "*"
        token => raise UnexpectedToken(token.describe(), token.span)
      }
      let (name, _) = self.expect_name()
      Namespace(language~, name~, span=keyword.span)
    }
    _ => raise UnexpectedToken(keyword.describe(), keyword.span)
  }
}

///|
fn Parser::parse_enum(self : Parser, start : Span) -> Definition raise IdlError {
  let (name, _) = self.expect_name()
  self.expect_symbol('{')
  let members : Array[EnumMember] = []
  let mut next_value = 0
  while !self.eat_symbol('}') {
    let (member_name, span) = self.expect_name()
    let value = if self.eat_symbol('=') {
      match self.advance() {
        { kind: IntegerLiteral(value), .. } => value.to_int()
        token => raise UnexpectedToken(token.describe(), token.span)
      }
    } else {
      next_value
    }
    next_value = value + 1
    let annotations = self.parse_annotations()
    self.separator()
    members.push({ name: member_name, value, annotations, span, })
  }
  let annotations = self.parse_annotations()
  Enum(name~, members~, annotations~, span=start)
}

///|
fn Parser::parse_record(
  self : Parser,
  kind : String,
  start : Span,
) -> Definition raise IdlError {
  let (name, _) = self.expect_name()
  self.expect_symbol('{')
  let fields = self.parse_fields('}')
  let annotations = self.parse_annotations()
  match kind {
    "struct" => Struct(name~, fields~, annotations~, span=start)
    "union" => Union(name~, fields~, annotations~, span=start)
    _ => Exception(name~, fields~, annotations~, span=start)
  }
}

///|
fn Parser::parse_function(self : Parser) -> FunctionDef raise IdlError {
  let start = self.current().span
  let oneway = self.eat_word("oneway")
  let return_type = self.parse_type()
  let (name, _) = self.expect_name()
  self.expect_symbol('(')
  let arguments = self.parse_fields(')')
  let throws = if self.eat_word("throws") {
    self.expect_symbol('(')
    self.parse_fields(')')
  } else {
    []
  }
  let annotations = self.parse_annotations()
  self.separator()
  { name, return_type, arguments, throws, oneway, annotations, span: start, }
}

///|
fn Parser::parse_service(
  self : Parser,
  start : Span,
) -> Definition raise IdlError {
  let (name, _) = self.expect_name()
  let extends = if self.eat_word("extends") {
    let (base, _) = self.expect_name()
    Some(base)
  } else {
    None
  }
  self.expect_symbol('{')
  let functions : Array[FunctionDef] = []
  while !self.eat_symbol('}') {
    functions.push(self.parse_function())
  }
  let annotations = self.parse_annotations()
  Service(name~, extends~, functions~, annotations~, span=start)
}

///|
fn Parser::parse_definition(self : Parser) -> Definition raise IdlError {
  let keyword = self.advance()
  match keyword.kind {
    Identifier("const") => {
      let ty = self.parse_type()
      let (name, _) = self.expect_name()
      self.expect_symbol('=')
      let value = self.parse_const_value()
      self.separator()
      Const(name~, ty~, value~, span=keyword.span)
    }
    Identifier("typedef") => {
      let target = self.parse_type()
      let (name, _) = self.expect_name()
      let annotations = self.parse_annotations()
      self.separator()
      Typedef(name~, target~, annotations~, span=keyword.span)
    }
    Identifier("enum") => self.parse_enum(keyword.span)
    Identifier("struct") => self.parse_record("struct", keyword.span)
    Identifier("union") => self.parse_record("union", keyword.span)
    Identifier("exception") => self.parse_record("exception", keyword.span)
    Identifier("service") => self.parse_service(keyword.span)
    _ => raise UnexpectedToken(keyword.describe(), keyword.span)
  }
}

///|
/// Parses a complete Apache Thrift IDL document.
pub fn parse_idl(
  input : String,
  source? : String = "<memory>",
) -> Schema raise IdlError {
  let parser = { tokens: lex(input, source~), index: 0, }
  let headers : Array[Header] = []
  while parser.is_word("include") ||
        parser.is_word("cpp_include") ||
        parser.is_word("namespace") {
    headers.push(parser.parse_header())
    parser.separator()
  }
  let definitions : Array[Definition] = []
  while !(parser.current().kind is End) {
    definitions.push(parser.parse_definition())
  }
  { source, headers, definitions, }
}
