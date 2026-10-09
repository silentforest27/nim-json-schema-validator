import std/json

type
  SchemaKind = enum
    SString, SNumber, SBoolean, SObject, SArray

  SchemaValue =
    case kind: SchemaKind
    of SString:
      minLength: Option[int]
      maxLength: Option[int]
      enumValues: Option[seq[string]]
      pattern: Option[string]
    of SNumber:
      minVal: Option[float]
      maxVal: Option[float]
      multipleOf: Option[float]
      enumValues: Option[seq[float]]
    of SBoolean: 
      enumValues: Option[seq[bool]]
    of SObject: 
      properties: Table[string, SchemaValue]
      required: seq[string]
      additionalProperties: Option[bool]
    of SArray: 
      items: SchemaValue
      minItems: Option[int]
      maxItems: Option[int]
      enumValues: Option[seq[JsonNode]]

  ValidationResult =
    object
      isValid: bool
      error: string