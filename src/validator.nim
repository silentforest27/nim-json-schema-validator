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
            # In a more advanced version, we could check a 'required' list
            return ValidationResult(isValid: false, error: "Missing property: " & key)
          let res = validate(data[key], sVal)
          if not res.isValid:
            return ValidationResult(isValid: false, error: "Property " & key & ": " & res.error)
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected object")

proc parseSchema(node: JsonNode): SchemaValue =
  if node.kind == JString:
    case node.getStr()
    of "string": return SchemaValue(kind: SString)
    of "number": return SchemaValue(kind: SNumber)
    of "boolean": return SchemaValue(kind: SBoolean)
    else: raise newException(ValueError, "Unknown type: " & node.getStr())
  
  elif node.kind == JObject:
    # Support explicit "type" key
    if node.hasKey("type"):
      let typeNode = node["type"]
      if typeNode.kind == JString:
        let typeStr = typeNode.getStr()
        case typeStr
        of "string": return SchemaValue(kind: SString)
        of "number": return SchemaValue(kind: SNumber)
        of "boolean": return SchemaValue(kind: SBoolean)
        of "array":
          if node.hasKey("items"):
            return SchemaValue(kind: SArray, items: parseSchema(node["items"]))
          raise newException(ValueError, "Array schema must define 'items'")
        of "object":
          var props = initTable[string, SchemaValue]()
          if node.hasKey("properties"):
            let propsNode = node["properties"]
            if propsNode.kind == JObject:
              for key, val in propsNode.fields:
                props[key] = parseSchema(val)
            else:
              raise newException(ValueError, "'properties' must be an object")
          return SchemaValue(kind: SObject, properties: props)
        else: raise newException(ValueError, "Unknown type: " & typeStr)

    # Fallback to the basic heuristic for backward compatibility
    var props = initTable[string, SchemaValue]()
    for key, val in node.fields:
      props[key] = parseSchema(val)
    return SchemaValue(kind: SObject, properties: props)

  elif node.kind == JArray:
    if node.len > 0:
      return SchemaValue(kind: SArray, items: parseSchema(node[0]))
    raise newException(ValueError, "Empty array in schema definition")

  raise newException(ValueError, "Invalid schema node")