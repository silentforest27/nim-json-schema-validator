import std/json

type
  SchemaKind = enum
    SString, SNumber, SBoolean, SObject, SArray

  SchemaValue =
    case kind: SchemaKind
    of SString:
      minLength: Option[int]
      maxLength: Option[int]
    of SNumber:
      minVal: Option[float]
      maxVal: Option[float]
    of SBoolean: discard
    of SObject: 
      properties: Table[string, SchemaValue]
      required: seq[string]
    of SArray: items: SchemaValue

  ValidationResult =
    object
      isValid: bool
      error: string