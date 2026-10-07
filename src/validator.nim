import std/[json, tables, options]
import types

proc validate(data: JsonNode, schema: SchemaValue): ValidationResult =
  case schema.kind
    of SString:
      if data.kind == JString:
        let val = data.getStr()
        if schema.minLength.isSome and val.len < schema.minLength.get():
          return ValidationResult(isValid: false, error: "String length " & $val.len & " is less than minimum " & $schema.minLength.get())
        if schema.maxLength.isSome and val.len > schema.maxLength.get():
          return ValidationResult(isValid: false, error: "String length " & $val.len & " is greater than maximum " & $schema.maxLength.get())
        if schema.enumValues.isSome:
          if val not in schema.enumValues.get():
            return ValidationResult(isValid: false, error: "Value " & val & " is not in allowed enum")
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected string")
    of SNumber:
      if data.kind == JFloat:
        let val = data.getFloat()
        if schema.minVal.isSome and val < schema.minVal.get():
          return ValidationResult(isValid: false, error: "Value " & $val & " is less than minimum " & $schema.minVal.get())
        if schema.maxVal.isSome and val > schema.maxVal.get():
          return ValidationResult(isValid: false, error: "Value " & $val & " is greater than maximum " & $schema.maxVal.get())
        if schema.enumValues.isSome:
          if val not in schema.enumValues.get():
            return ValidationResult(isValid: false, error: "Value " & $val & " is not in allowed enum")
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected number")
    of SBoolean:
      if data.kind == JBool:
        let val = data.getBool()
        if schema.enumValues.isSome:
          if val not in schema.enumValues.get():
            return ValidationResult(isValid: false, error: "Value " & $val & " is not in allowed enum")
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected boolean")
    of SArray:
      if data.kind == JArray:
        if schema.enumValues.isSome:
          # Simple structural equality check for arrays in enum
          if data not in schema.enumValues.get():
            return ValidationResult(isValid: false, error: "Array value is not in allowed enum")
        for item in data:
          let res = validate(item, schema.items)
          if not res.isValid: return res
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected array")
    of SObject:
      if data.kind == JObject:
        # Check required properties first
        for req in schema.required:
          if not data.hasKey(req):
            return ValidationResult(isValid: false, error: "Missing required property: " & req)
        
        # Validate existing properties
        for key, sVal in schema.properties:
          if data.hasKey(key):
            let res = validate(data[key], sVal)
            if not res.isValid:
              return ValidationResult(isValid: false, error: "Property " & key & ": " & res.error)

        # Check additional properties
        if schema.additionalProperties.isSome and schema.additionalProperties.get() == false:
          for key in data.fields.keys:
            if not schema.properties.hasKey(key):
              return ValidationResult(isValid: false, error: "Additional property not allowed: " & key)

        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected object")

proc parseEnum(node: JsonNode, kind: SchemaKind): Option[seq[JsonNode]] =
  if node.kind == JArray:
    return some(node)
  raise newException(ValueError, "'enum' must be an array")

proc parseSchema(node: JsonNode): SchemaValue =
  if node.kind == JString:
    case node.getStr()
    of "string": return SchemaValue(kind: SString, minLength: none(int), maxLength: none(int), enumValues: none(seq[string]))
    of "number": return SchemaValue(kind: SNumber, minVal: none(float), maxVal: none(float), enumValues: none(seq[float]))
    of "boolean": return SchemaValue(kind: SBoolean, enumValues: none(seq[bool]))
    else: raise newException(ValueError, "Unknown type: " & node.getStr())
  
  elif node.kind == JObject:
    if node.hasKey("type"):
      let typeNode = node["type"]
      if typeNode.kind == JString:
        let typeStr = typeNode.getStr()
        case typeStr
        of "string":
          var minL = none(int)
          var maxL = none(int)
          var enumV = none(seq[string])
          if node.hasKey("minLength") and node["minLength"].kind == JInt:
            minL = some(node["minLength"].getInt())
          if node.hasKey("maxLength") and node["maxLength"].kind == JInt:
            maxL = some(node["maxLength"].getInt())
          if node.hasKey("enum"):
            let enumNodes = parseEnum(node["enum"], SString).get()
            var values: seq[string] = @[]
            for e in enumNodes:
              if e.kind == JString: values.add(e.getStr())
              else: raise newException(ValueError, "Enum values for string type must be strings")
            enumV = some(values)
          return SchemaValue(kind: SString, minLength: minL, maxLength: maxL, enumValues: enumV)
        of "number":
          var minV = none(float)
          var maxV = none(float)
          var enumV = none(seq[float])
          if node.hasKey("minimum") and node["minimum"].kind == JFloat:
            minV = some(node["minimum"].getFloat())
          if node.hasKey("maximum") and node["maximum"].kind == JFloat:
            maxV = some(node["maximum"].getFloat())
          if node.hasKey("enum"):
            let enumNodes = parseEnum(node["enum"], SNumber).get()
            var values: seq[float] = @[]
            for e in enumNodes:
              if e.kind == JFloat: values.add(e.getFloat())
              elif e.kind == JInt: values.add(e.getInt().float)
              else: raise newException(ValueError, "Enum values for number type must be numbers")
            enumV = some(values)
          return SchemaValue(kind: SNumber, minVal: minV, maxVal: maxV, enumValues: enumV)
        of "boolean": 
          var enumV = none(seq[bool])
          if node.hasKey("enum"):
            let enumNodes = parseEnum(node["enum"], SBoolean).get()
            var values: seq[bool] = @[]
            for e in enumNodes:
              if e.kind == JBool: values.add(e.getBool())
              else: raise newException(ValueError, "Enum values for boolean type must be booleans")
            enumV = some(values)
          return SchemaValue(kind: SBoolean, enumValues: enumV)
        of "array":
          if node.hasKey("items"):
            var enumV = none(seq[JsonNode])
            if node.hasKey("enum"):
              enumV = parseEnum(node["enum"], SArray)
            return SchemaValue(kind: SArray, items: parseSchema(node["items"]), enumValues: enumV)
          raise newException(ValueError, "Array schema must define 'items'")
        of "object":
          var props = initTable[string, SchemaValue]()
          var reqs: seq[string] = @[]
          var addProps = none(bool)
          
          if node.hasKey("properties"):
            let propsNode = node["properties"]
            if propsNode.kind == JObject:
              for key, val in propsNode.fields:
                props[key] = parseSchema(val)
            else:
              raise newException(ValueError, "'properties' must be an object")
          
          if node.hasKey("required"):
            let reqsNode = node["required"]
            if reqsNode.kind == JArray:
              for item in reqsNode:
                if item.kind == JString:
                  reqs.add(item.getStr())
                else:
                  raise newException(ValueError, "'required' array must contain strings")
            else:
              raise newException(ValueError, "'required' must be an array")

          if node.hasKey("additionalProperties"):
            let apNode = node["additionalProperties"]
            if apNode.kind == JBool:
              addProps = some(apNode.getBool())
            else:
              raise newException(ValueError, "'additionalProperties' must be a boolean")
              
          return SchemaValue(kind: SObject, properties: props, required: reqs, additionalProperties: addProps)
        else: raise newException(ValueError, "Unknown type: " & typeStr)

    # Fallback to the basic heuristic
    var props = initTable[string, SchemaValue]()
    for key, val in node.fields:
      props[key] = parseSchema(val)
    return SchemaValue(kind: SObject, properties: props, required: @[], additionalProperties: none(bool))

  elif node.kind == JArray:
    if node.len > 0:
      return SchemaValue(kind: SArray, items: parseSchema(node[0]))
    raise newException(ValueError, "Empty array in schema definition")

  raise newException(ValueError, "Invalid schema node")