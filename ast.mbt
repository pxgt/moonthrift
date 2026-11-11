///|
/// Primitive types defined by the Thrift IDL.
#derive(Debug, Eq)
pub(all) enum BaseType {
  Bool
  Byte
  I16
  I32
  I64
  Double
  String
  Binary
  Uuid
  Void
}

///|
/// A primitive, named, or container type reference.
#derive(Debug, Eq)
pub(all) enum TypeRef {
  Base(BaseType)
  Named(String)
  List(TypeRef)
  Set(TypeRef)
  Map(TypeRef, TypeRef)
  CppType(TypeRef, String)
}

///|
/// A constant expression accepted by Thrift IDL.
#derive(Debug, Eq)
pub(all) enum ConstValue {
  BoolValue(Bool)
  IntegerValue(Int64)
  DoubleValue(Double)
  StringValue(String)
  IdentifierValue(String)
  ListValue(Array[ConstValue])
  MapValue(Array[(ConstValue, ConstValue)])
}

///|
#derive(Debug, Eq)
pub(all) enum Requiredness {
  Default
  Required
  Optional
}

///|
/// One key/value annotation attached to an IDL item.
#derive(Debug, Eq)
pub(all) struct Annotation {
  key : String
  value : String?
}

///|
/// A field in a struct, union, exception, function, or throws clause.
#derive(Debug, Eq)
pub(all) struct Field {
  id : Int32
  requiredness : Requiredness
  ty : TypeRef
  name : String
  default_value : ConstValue?
  annotations : Array[Annotation]
  span : Span
}

///|
#derive(Debug, Eq)
pub(all) enum Header {
  Include(path~ : String, span~ : Span)
  Namespace(language~ : String, name~ : String, span~ : Span)
  CppInclude(path~ : String, span~ : Span)
}

///|
#derive(Debug, Eq)
pub(all) struct EnumMember {
  name : String
  value : Int32
  annotations : Array[Annotation]
  span : Span
}

///|
#derive(Debug, Eq)
pub(all) struct FunctionDef {
  name : String
  return_type : TypeRef
  arguments : Array[Field]
  throws : Array[Field]
  oneway : Bool
  annotations : Array[Annotation]
  span : Span
}

///|
#derive(Debug, Eq)
pub(all) enum Definition {
  Const(
    name~ : String,
    ty~ : TypeRef,
    value~ : ConstValue,
    annotations~ : Array[Annotation],
    span~ : Span
  )
  Typedef(
    name~ : String,
    target~ : TypeRef,
    annotations~ : Array[Annotation],
    span~ : Span
  )
  Enum(
    name~ : String,
    members~ : Array[EnumMember],
    annotations~ : Array[Annotation],
    span~ : Span
  )
  Struct(
    name~ : String,
    fields~ : Array[Field],
    annotations~ : Array[Annotation],
    span~ : Span
  )
  Union(
    name~ : String,
    fields~ : Array[Field],
    annotations~ : Array[Annotation],
    span~ : Span
  )
  Exception(
    name~ : String,
    fields~ : Array[Field],
    annotations~ : Array[Annotation],
    span~ : Span
  )
  Service(
    name~ : String,
    extends~ : String?,
    functions~ : Array[FunctionDef],
    annotations~ : Array[Annotation],
    span~ : Span
  )
}

///|
/// A parsed Thrift file. Semantic diagnostics are produced separately by
/// `check_schema` so tools can still inspect a syntactically valid AST.
#derive(Debug, Eq)
pub(all) struct Schema {
  source : String
  headers : Array[Header]
  definitions : Array[Definition]
}

///|
pub fn Definition::name(self : Definition) -> String {
  match self {
    Const(name~, ..)
    | Typedef(name~, ..)
    | Enum(name~, ..)
    | Struct(name~, ..)
    | Union(name~, ..)
    | Exception(name~, ..)
    | Service(name~, ..) => name
  }
}
