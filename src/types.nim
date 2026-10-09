import std/json

type
  SchemaKind = enum
    SString, SNumber, SInteger, SBoolean, SObject, SArray, SAnyOf, SAllOf, SOneOf, SNot

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
      exclusiveMin: Option[float]
      exclusiveMax: Option[float]
      multipleOf: Option[float]
      enumValues: Option[seq[float]]
    of SInteger:
      minVal: Option[float]
      maxVal: Option[float]
      exclusiveMin: Option[float]
      exclusiveMax: Option[float]
      multipleOf: Option[float]
      enumValues: Option[seq[float]]
    of SBoolean: 
      enumValues: Option[seq[bool]]
    of SObject: 
      properties: Table[string, SchemaValue]
      required: seq[string]
      additionalProperties: Option[bool]
      minProperties: Option[int]
      maxProperties: Option[int]
      dependencies: Option[Table[string, seq[string]]]
    of SArray: 
      items: SchemaValue
      minItems: Option[int]
      maxItems: Option[int]
      enumValues: Option[seq[JsonNode]]
    of SAnyOf:
      schemas: seq[SchemaValue]
    of SAllOf:
      schemas: seq[SchemaValue]
    of SOneOf:
      schemas: seq[SchemaValue]
    of SNot:
      schema: SchemaValue

  ValidationResult =
    object
      isValid: bool
      error: string