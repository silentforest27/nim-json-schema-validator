import std/[json, tables, options, re, math]
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
        if schema.pattern.isSome:
          if not val.contains(pcre(schema.pattern.get())):
            return ValidationResult(isValid: false, error: "Value " & val & " does not match pattern " & schema.pattern.get())
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected string")
    of SNumber, SInteger:
      if data.kind == JFloat or data.kind == JInt:
        if schema.kind == SInteger and data.kind == JFloat:
          # Check if float is actually an integer
          let val = data.getFloat()
          if val != floor(val):
            return ValidationResult(isValid: false, error: "Expected integer")

        let val = data.getFloat()
        if schema.minVal.isSome and val < schema.minVal.get():
          return ValidationResult(isValid: false, error: "Value " & $val & " is less than minimum " & $schema.minVal.get())
        if schema.maxVal.isSome and val > schema.maxVal.get():
          return ValidationResult(isValid: false, error: "Value " & $val & " is greater than maximum " & $schema.maxVal.get())
        if schema.exclusiveMin.isSome and val <= schema.exclusiveMin.get():
          return ValidationResult(isValid: false, error: "Value " & $val & " must be strictly greater than " & $schema.exclusiveMin.get())
        if schema.exclusiveMax.isSome and val >= schema.exclusiveMax.get():
          return ValidationResult(isValid: false, error: "Value " & $val & " must be strictly less than " & $schema.exclusiveMax.get())
        if schema.multipleOf.isSome:
          let modVal = schema.multipleOf.get()
          # Use fmod for float modulo check
          if abs(fmod(val, modVal)) > 1e-9 and abs(fmod(val, modVal) - modVal) > 1e-9:
            return ValidationResult(isValid: false, error: "Value " & $val & " is not a multiple of " & $modVal)
        if schema.enumValues.isSome:
          if val not in schema.enumValues.get():
            return ValidationResult(isValid: false, error: "Value " & $val & " is not in allowed enum")
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: if schema.kind == SInteger then "Expected integer" else "Expected number")
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
        
        if schema.minItems.isSome and data.len < schema.minItems.get():
          return ValidationResult(isValid: false, error: "Array length " & $data.len & " is less than minimum " & $schema.minItems.get())
        if schema.maxItems.isSome and data.len > schema.maxItems.get():
          return ValidationResult(isValid: false, error: "Array length " & $data.len & " is greater than maximum " & $schema.maxItems.get())

        for item in data:
          let res = validate(item, schema.items)
          if not res.isValid: return res
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected array")
    of SObject:
      if data.kind == JObject:
        let propCount = data.fields.len
        if schema.minProperties.isSome and propCount < schema.minProperties.get():
          return ValidationResult(isValid: false, error: "Object has " & $propCount & " properties, which is less than minimum " & $schema.minProperties.get())
        if schema.maxProperties.isSome and propCount > schema.maxProperties.get():
          return ValidationResult(isValid: false, error: "Object has " & $propCount & " properties, which is greater than maximum " & $schema.maxProperties.get())

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

        # Validate pattern properties
        for pattern, sVal in schema.patternProperties:
          for key, val in data.fields:
            if key.contains(pcre(pattern)):
              let res = validate(val, sVal)
              if not res.isValid:
                return ValidationResult(isValid: false, error: "Property " & key & " (matched by " & pattern & "): " & res.error)

        # Check additional properties
        if schema.additionalProperties.isSome and schema.additionalProperties.get() == false:
          for key in data.fields.keys:
            var matched = false
            if schema.properties.hasKey(key):
              matched = true
            else:
              for pattern in schema.patternProperties.keys:
                if key.contains(pcre(pattern)):
                  matched = true
                  break
            if not matched:
              return ValidationResult(isValid: false, error: "Additional property not allowed: " & key)

        # Check property dependencies
        if schema.dependencies.isSome:
          let deps = schema.dependencies.get()
          for trigger, targets in deps:
            if data.hasKey(trigger):
              for target in targets:
                if not data.hasKey(target):
                  return ValidationResult(isValid: false, error: "Property " & trigger & " depends on " & target & " which is missing")

        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected object")
    of SAnyOf:
      var errors: seq[string] = @[]
      for s in schema.schemas:
        let res = validate(data, s)
        if res.isValid: return ValidationResult(isValid: true)
        errors.add(res.error)
      return ValidationResult(isValid: false, error: "Value must match at least one schema in anyOf. Errors: " & errors.join(", "))
    of SAllOf:
      for s in schema.schemas:
        let res = validate(data, s)
        if not res.isValid: return res
      return ValidationResult(isValid: true)
    of SOneOf:
      var matches = 0
      for s in schema.schemas:
        if validate(data, s).isValid:
          matches += 1
      if matches == 1:
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Value must match exactly one schema in oneOf, but matched " & $matches)
    of SNot:
      let res = validate(data, schema.schema)
      if not res.isValid:
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Value must not match the negated schema")

proc parseEnum(node: JsonNode, kind: SchemaKind): Option[seq[JsonNode]] =
  if node.kind == JArray:
    return some(node)
  raise newException(ValueError, "'enum' must be an array")

proc parseSchema(node: JsonNode): SchemaValue =
  if node.kind == JString:
    case node.getStr()
    of "string": return SchemaValue(kind: SString, minLength: none(int), maxLength: none(int), enumValues: none(seq[string]), pattern: none(string))
    of "number": return SchemaValue(kind: SNumber, minVal: none(float), maxVal: none(float), exclusiveMin: none(float), exclusiveMax: none(float), multipleOf: none(float), enumValues: none(seq[float]))
    of "integer": return SchemaValue(kind: SInteger, minVal: none(float), maxVal: none(float), exclusiveMin: none(float), exclusiveMax: none(float), multipleOf: none(float), enumValues: none(seq[float]))
    of "boolean": return SchemaValue(kind: SBoolean, enumValues: none(seq[bool]))
    else: raise newException(ValueError, "Unknown type: " & node.getStr())
  
  elif node.kind == JObject:
    if node.hasKey("not"):
      let notNode = node["not"]
      return SchemaValue(kind: SNot, schema: parseSchema(notNode))

    if node.hasKey("anyOf"):
      let anyOfNode = node["anyOf"]
      if anyOfNode.kind == JArray:
        var schemas: seq[SchemaValue] = @[]
        for s in anyOfNode:
          schemas.add(parseSchema(s))
        return SchemaValue(kind: SAnyOf, schemas: schemas)
      raise newException(ValueError, "'anyOf' must be an array")
    
    if node.hasKey("allOf"):
      let allOfNode = node["allOf"]
      if allOfNode.kind == JArray:
        var schemas: seq[SchemaValue] = @[]
        for s in allOfNode:
          schemas.add(parseSchema(s))
        return SchemaValue(kind: SAllOf, schemas: schemas)
      raise newException(ValueError, "'allOf' must be an array")

    if node.hasKey("oneOf"):
      let oneOfNode = node["oneOf"]
      if oneOfNode.kind == JArray:
        var schemas: seq[SchemaValue] = @[]
        for s in oneOfNode:
          schemas.add(parseSchema(s))
        return SchemaValue(kind: SOneOf, schemas: schemas)
      raise newException(ValueError, "'oneOf' must be an array")

    if node.hasKey("type"):
      let typeNode = node["type"]
      if typeNode.kind == JString:
        let typeStr = typeNode.getStr()
        case typeStr
        of "string":
          var minL = none(int)
          var maxL = none(int)
          var enumV = none(seq[string])
          var pat = none(string)
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
          if node.hasKey("pattern") and node["pattern"].kind == JString:
            pat = some(node["pattern"].getStr())
          return SchemaValue(kind: SString, minLength: minL, maxLength: maxL, enumValues: enumV, pattern: pat)
        of "number", "integer":
          let kind = if typeStr == "number" then SNumber else SInteger
          var minV = none(float)
          var maxV = none(float)
          var exMinV = none(float)
          var exMaxV = none(float)
          var multV = none(float)
          var enumV = none(seq[float])
          if node.hasKey("minimum"):
            let minNode = node["minimum"]
            if minNode.kind == JFloat: minV = some(minNode.getFloat())
            elif minNode.kind == JInt: minV = some(minNode.getInt().float)
            else: raise newException(ValueError, "'minimum' must be a number")
          if node.hasKey("maximum"):
            let maxNode = node["maximum"]
            if maxNode.kind == JFloat: maxV = some(maxNode.getFloat())
            elif maxNode.kind == JInt: maxV = some(maxNode.getInt().float)
            else: raise newException(ValueError, "'maximum' must be a number")
          if node.hasKey("exclusiveMinimum"):
            let exMinNode = node["exclusiveMinimum"]
            if exMinNode.kind == JFloat: exMinV = some(exMinNode.getFloat())
            elif exMinNode.kind == JInt: exMinV = some(exMinNode.getInt().float)
            else: raise newException(ValueError, "'exclusiveMinimum' must be a number")
          if node.hasKey("exclusiveMaximum"):
            let exMaxNode = node["exclusiveMaximum"]
            if exMaxNode.kind == JFloat: exMaxV = some(exMaxNode.getFloat())
            elif exMaxNode.kind == JInt: exMaxV = some(exMaxNode.getInt().float)
            else: raise newException(ValueError, "'exclusiveMaximum' must be a number")
          if node.hasKey("multipleOf"):
            let multNode = node["multipleOf"]
            if multNode.kind == JFloat: multV = some(multNode.getFloat())
            elif multNode.kind == JInt: multV = some(multNode.getInt().float)
            else: raise newException(ValueError, "'multipleOf' must be a number")
          if node.hasKey("enum"):
            let enumNodes = parseEnum(node["enum"], kind).get()
            var values: seq[float] = @[]
            for e in enumNodes:
              if e.kind == JFloat: values.add(e.getFloat())
              elif e.kind == JInt: values.add(e.getInt().float)
              else: raise newException(ValueError, "Enum values for number/integer type must be numbers")
            enumV = some(values)
          return SchemaValue(kind: kind, minVal: minV, maxVal: maxV, exclusiveMin: exMinV, exclusiveMax: exMaxV, multipleOf: multV, enumValues: enumV)
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
            var minI = none(int)
            var maxI = none(int)
            var enumV = none(seq[JsonNode])
            if node.hasKey("minItems") and node["minItems"].kind == JInt:
              minI = some(node["minItems"].getInt())
            if node.hasKey("maxItems") and node["maxItems"].kind == JInt:
              maxI = some(node["maxItems"].getInt())
            if node.hasKey("enum"):
              enumV = parseEnum(node["enum"], SArray)
            return SchemaValue(kind: SArray, items: parseSchema(node["items"]), minItems: minI, maxItems: maxI, enumValues: enumV)
          raise newException(ValueError, "Array schema must define 'items'")
        of "object":
          var props = initTable[string, SchemaValue]()
          var patProps = initTable[string, SchemaValue]()
          var reqs: seq[string] = @[]
          var addProps = none(bool)
          var minP = none(int)
          var maxP = none(int)
          var deps = none(Table[string, seq[string]])
          
          if node.hasKey("properties"):
            let propsNode = node["properties"]
            if propsNode.kind == JObject:
              for key, val in propsNode.fields:
                props[key] = parseSchema(val)
            else:
              raise newException(ValueError, "'properties' must be an object")
          
          if node.hasKey("patternProperties"):
            let patPropsNode = node["patternProperties"]
            if patPropsNode.kind == JObject:
              for key, val in patPropsNode.fields:
                patProps[key] = parseSchema(val)
            else:
              raise newException(ValueError, "'patternProperties' must be an object")

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

          if node.hasKey("minProperties") and node["minProperties"].kind == JInt:
            minP = some(node["minProperties"].getInt())
          if node.hasKey("maxProperties") and node["maxProperties"].kind == JInt:
            maxP = some(node["maxProperties"].getInt())

          if node.hasKey("dependencies"):
            let depsNode = node["dependencies"]
            if depsNode.kind == JObject:
              var depsTable = initTable[string, seq[string]]()
              for key, val in depsNode.fields:
                if val.kind == JArray:
                  var targets: seq[string] = @[]
                  for target in val:
                    if target.kind == JString: targets.add(target.getStr())
                    else: raise newException(ValueError, "Dependency targets must be strings")
                  depsTable[key] = targets
                else:
                  raise newException(ValueError, "Dependency value must be an array of strings")
              deps = some(depsTable)
            else:
              raise newException(ValueError, "'dependencies' must be an object")
              
          return SchemaValue(kind: SObject, properties: props, patternProperties: patProps, required: reqs, additionalProperties: addProps, minProperties: minP, maxProperties: maxP, dependencies: deps)
        else: raise newException(ValueError, "Unknown type: " & typeStr)

    # Fallback to the basic heuristic
    var props = initTable[string, SchemaValue]()
    for key, val in node.fields:
      props[key] = parseSchema(val)
    return SchemaValue(kind: SObject, properties: props, patternProperties: initTable[string, SchemaValue](), required: @[], additionalProperties: none(bool), minProperties: none(int), maxProperties: none(int), dependencies: none(Table[string, seq[string]]))

  elif node.kind == JArray:
    if node.len > 0:
      return SchemaValue(kind: SArray, items: parseSchema(node[0]), minItems: none(int), maxItems: none(int), enumValues: none(seq[JsonNode]))
    raise newException(ValueError, "Empty array in schema definition")

  raise newException(ValueError, "Invalid schema node")