import std/json

type
  SchemaKind = enum
    SString, SNumber, SInteger, SBoolean, SObject, SArray, SAnyOf, SAllOf, SOneOf, SNot, SConst, SNull, SConditional

  SchemaValue =
    case kind: SchemaKind
    of SString:
      minLength: Option[int]
      maxLength: Option[int]
      enumValues: Option[seq[string]]
      pattern: Option[string]
      format: Option[string]
      defaultValue: Option[JsonNode]
      readOnly: Option[bool]
      writeOnly: Option[bool]
    of SNumber:
      minVal: Option[float]
      maxVal: Option[float]
      exclusiveMin: Option[float]
      exclusiveMax: Option[float]
      multipleOf: Option[float]
      enumValues: Option[seq[float]]
      defaultValue: Option[JsonNode]
      readOnly: Option[bool]
      writeOnly: Option[bool]
    of SInteger:
      minVal: Option[float]
      maxVal: Option[float]
      exclusiveMin: Option[float]
      exclusiveMax: Option[float]
      multipleOf: Option[float]
      enumValues: Option[seq[float]]
      defaultValue: Option[JsonNode]
      readOnly: Option[bool]
      writeOnly: Option[bool]
    of SBoolean: 
      enumValues: Option[seq[bool]]
      defaultValue: Option[JsonNode]
      readOnly: Option[bool]
      writeOnly: Option[bool]
    of SObject: 
      properties: Table[string, SchemaValue]
      patternProperties: Table[string, SchemaValue]
      required: seq[string]
      additionalProperties: Option[AdditionalProperties]
      minProperties: Option[int]
      maxProperties: Option[int]
      dependencies: Option[Table[string, Dependency]]
      dependentRequired: Option[Table[string, seq[string]]]
      dependentSchemas: Option[Table[string, SchemaValue]]
      propertyNames: Option[SchemaValue]
      defaultValue: Option[JsonNode]
      readOnly: Option[bool]
      writeOnly: Option[bool]
    of SArray: 
      items: ArrayItems
      additionalItems: Option[SchemaValue]
      minItems: Option[int]
      maxItems: Option[int]
      uniqueItems: Option[bool]
      enumValues: Option[seq[JsonNode]]
      defaultValue: Option[JsonNode]
      readOnly: Option[bool]
      writeOnly: Option[bool]
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
    of SNull:
      defaultValue: Option[JsonNode]
      readOnly: Option[bool]
      writeOnly: Option[bool]
    of SConditional:
      ifSchema: SchemaValue
      thenSchema: Option[SchemaValue]
      elseSchema: Option[SchemaValue]

  AdditionalProperties =
    case kind: AdditionalPropertiesKind
    of BoolProp: value: bool
    of SchemaProp: schema: SchemaValue

  AdditionalPropertiesKind = enum
    BoolProp, SchemaProp

  Dependency =
    case kind: DependencyKind
    of PropertyDeps: targets: seq[string]
    of SchemaDep: schema: SchemaValue

  DependencyKind = enum
    PropertyDeps, SchemaDep

  ArrayItems =
    case kind: ArrayItemsKind
    of Single: schema: SchemaValue
    of Positional: schemas: seq[SchemaValue]

  ArrayItemsKind = enum
    Single, Positional

  ValidationResult =
    object
      isValid: bool
      error: string