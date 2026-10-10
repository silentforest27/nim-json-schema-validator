import std/json

type
  SchemaKind = enum
    SString, SNumber, SInteger, SBoolean, SObject, SArray, SAnyOf, SAllOf, SOneOf, SNot, SConst

  SchemaValue =
    case kind: SchemaKind
    of SString:
      minLength: Option[int]
      maxLength: Option[int]
      enumValues: Option[seq[string]]
      pattern: Option[string]
      defaultValue: Option[JsonNode]
    of SNumber:
      minVal: Option[float]
      maxVal: Option[float]
      exclusiveMin: Option[float]
      exclusiveMax: Option[float]
      multipleOf: Option[float]
      enumValues: Option[seq[float]]
      defaultValue: Option[JsonNode]
    of SInteger:
      minVal: Option[float]
      maxVal: Option[float]
      exclusiveMin: Option[float]
      exclusiveMax: Option[float]
      multipleOf: Option[float]
      enumValues: Option[seq[float]]
      defaultValue: Option[JsonNode]
    of SBoolean: 
      enumValues: Option[seq[bool]]
      defaultValue: Option[JsonNode]
    of SObject: 
      properties: Table[string, SchemaValue]
      patternProperties: Table[string, SchemaValue]
      required: seq[string]
      additionalProperties: Option[bool]
      minProperties: Option[int]
      maxProperties: Option[int]
      dependencies: Option[Table[string, seq[string]]]
      defaultValue: Option[JsonNode]
    of SArray: 
      items: SchemaValue
      minItems: Option[int]
      maxItems: Option[int]
      uniqueItems: Option[bool]
      enumValues: Option[seq[JsonNode]]
      defaultValue: Option[JsonNode]
    of SAnyOf:
      schemas: seq[SchemaValue]
    of SAllOf:
      schemas: seq[SchemaValue]
    of SOneOf:
      schemas: seq[SchemaValue]
    of SNot:
      schema: SchemaValue
    of SConst:
      value: JsonNode

  ValidationResult =
    object
      isValid: bool
      error: string