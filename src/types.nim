import std/json

type
  SchemaKind = enum
    SString, SNumber, SBoolean, SObject, SArray

  SchemaValue =
    case kind: SchemaKind
    of SString, SBoolean: discard
    of SNumber:
      minVal: Option[float]
      maxVal: Option[float]
    of SObject: 
      properties: Table[string, SchemaValue]
      required: seq[string]
    of SArray: items: SchemaValue

  ValidationResult =
    object
      isValid: bool
      error: string