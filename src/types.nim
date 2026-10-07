import std/json

type
  SchemaKind = enum
    SString, SNumber, SBoolean, SObject, SArray

  SchemaValue =
    case kind: SchemaKind
    of SString, SNumber, SBoolean: discard
    of SObject: 
      properties: Table[string, SchemaValue]
      required: seq[string]
    of SArray: items: SchemaValue

  ValidationResult =
    object
      isValid: bool
      error: string