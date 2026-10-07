import std/[json, tables]
import types

proc validate(data: JsonNode, schema: SchemaValue): ValidationResult =
  case schema.kind
    of SString:
      if data.kind == JString:
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected string")
    of SNumber:
      if data.kind == JFloat:
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected number")
    of SBoolean:
      if data.kind == JBool:
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected boolean")
    of SArray:
      if data.kind == JArray:
        for item in data:
          let res = validate(item, schema.items)
          if not res.isValid: return res
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected array")
    of SObject:
      if data.kind == JObject:
        for key, sVal in schema.properties:
          if not data.hasKey(key):
            return ValidationResult(isValid: false, error: "Missing property: " & key)
          let res = validate(data[key], sVal)
          if not res.isValid:
            return ValidationResult(isValid: false, error: "Property " & key & ": " & res.error)
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected object")

proc parseSchema(node: JsonNode): SchemaValue =
  # Simplified schema parser: assumes a basic format where a string defines the type
  # In a full implementation, this would handle the full JSON Schema spec
  if node.kind == JString:
    case node.getStr()
    of "string": return SchemaValue(kind: SString)
    of "number": return SchemaValue(kind: SNumber)
    of "boolean": return SchemaValue(kind: SBoolean)
    else: raise newException(ValueError, "Unknown type")
  elif node.kind == JObject:
    # This is a very basic heuristic for the example
    var props = initTable[string, SchemaValue]()
    for key, val in node.fields:
      props[key] = parseSchema(val)
    return SchemaValue(kind: SObject, properties: props)
  elif node.kind == JArray:
    return SchemaValue(kind: SArray, items: parseSchema(node[0]))
  raise newException(ValueError, "Invalid schema node")