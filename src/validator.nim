import std/[json, tables, options, re, math, sets]
import types

proc validateFormat(val: string, format: string): bool =
  case format
  of "date-time":
    # Simplified ISO 8601 check
    return val.contains(pcre(^"\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(Z|[+-]\\d{2}:?\\d{2})?$"))
  of "email":
    return val.contains(pcre(^"[\\w\.-]+@[\\w\.-]+\\.[a-zA-Z]{2,}$"))
  of "ipv4":
    return val.contains(pcre(^"(\\d{1,3}\\.){3}\\d{1,3}$"))
  of "ipv6":
    return val.contains(pcre(^"([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$"))
  else:
    return true # Ignore unknown formats

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
        if schema.format.isSome:
          if not validateFormat(val, schema.format.get()):
            return ValidationResult(isValid: false, error: "Value " & val & " does not match format " & schema.format.get())
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected string")
    of SNumber, SInteger:
      if data.kind == JFloat or data.kind == JInt:
        if schema.kind == SInteger and data.kind == JFloat:
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
          let remainder = abs(fmod(val, modVal))
          if remainder > 1e-9 and abs(remainder - modVal) > 1e-9:
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
          if data not in schema.enumValues.get():
            return ValidationResult(isValid: false, error: "Array value is not in allowed enum")
        if schema.minItems.isSome and data.len < schema.minItems.get():
          return ValidationResult(isValid: false, error: "Array length " & $data.len & " is less than minimum " & $schema.minItems.get())
        if schema.maxItems.isSome and data.len > schema.maxItems.get():
          return ValidationResult(isValid: false, error: "Array length " & $data.len & " is greater than maximum " & $schema.maxItems.get())
        if schema.uniqueItems.isSome and schema.uniqueItems.get() == true:
          var seen: seq[JsonNode] = @[]
          for item in data:
            if item in seen:
              return ValidationResult(isValid: false, error: "Array contains duplicate items")
            seen.add(item)
        case schema.items.kind
        of Single:
          for i, item in data:
            let res = validate(item, schema.items.schema)
            if not res.isValid: return ValidationResult(isValid: false, error: "Item at index " & $i & ": " & res.error)
        of Positional:
          let schemas = schema.items.schemas
          for i in 0 ..< data.len:
            if i < schemas.len:
              let res = validate(data[i], schemas[i])
              if not res.isValid: return ValidationResult(isValid: false, error: "Item at index " & $i & ": " & res.error)
            elif schema.additionalItems.isSome:
              let res = validate(data[i], schema.additionalItems.get())
              if not res.isValid: return ValidationResult(isValid: false, error: "Additional item at index " & $i & ": " & res.error)
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected array")
    of SObject:
      if data.kind == JObject:
        let propCount = data.fields.len
        if schema.minProperties.isSome and propCount < schema.minProperties.get():
          return ValidationResult(isValid: false, error: "Object has " & $propCount & " properties, which is less than minimum " & $schema.minProperties.get())
        if schema.maxProperties.isSome and propCount > schema.maxProperties.get():
          return ValidationResult(isValid: false, error: "Object has " & $propCount & " properties, which is greater than maximum " & $schema.maxProperties.get())
        for req in schema.required:
          if not data.hasKey(req):
            return ValidationResult(isValid: false, error: "Missing required property: " & req)
        for key, sVal in schema.properties:
          if data.hasKey(key):
            let res = validate(data[key], sVal)
            if not res.isValid:
              return ValidationResult(isValid: false, error: "Property " & key & ": " & res.error)
        for pattern, sVal in schema.patternProperties:
          for key, val in data.fields:
            if key.contains(pcre(pattern)):
              let res = validate(val, sVal)
              if not res.isValid:
                return ValidationResult(isValid: false, error: "Property " & key & " (matched by " & pattern & "): " & res.error)
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
        if schema.dependencies.isSome:
          let deps = schema.dependencies.get()
          for trigger, dep in deps:
            if data.hasKey(trigger):
              case dep.kind
              of PropertyDeps:
                for target in dep.targets:
                  if not data.hasKey(target):
                    return ValidationResult(isValid: false, error: "Property " & trigger & " depends on " & target & " which is missing")
              of SchemaDep:
                let res = validate(data, dep.schema)
                if not res.isValid:
                  return ValidationResult(isValid: false, error: "Property " & trigger & " triggers dependency schema validation: " & res.error)
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
    of SConst:
      if data == schema.value:
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Value does not match constant " & $schema.value)
    of SNull:
      if data.kind == JNull:
        return ValidationResult(isValid: true)
      return ValidationResult(isValid: false, error: "Expected null")

proc parseEnum(node: JsonNode, kind: SchemaKind): Option[seq[JsonNode]] =
  if node.kind == JArray:
    return some(node)
  raise newException(ValueError, "'enum' must be an array")

proc parseSchema(node: JsonNode): SchemaValue =
  if node.kind == JString:
    case node.getStr()
    of "string": return SchemaValue(kind: SString, minLength: none(int), maxLength: none(int), enumValues: none(seq[string]), pattern: none(string), format: none(string), defaultValue: none(JsonNode), readOnly: none(bool), writeOnly: none(bool))
    of "number": return SchemaValue(kind: SNumber, minVal: none(float), maxVal: none(float), exclusiveMin: none(float), exclusiveMax: none(float), multipleOf: none(float), enumValues: none(seq[float]), defaultValue: none(JsonNode), readOnly: none(bool), writeOnly: none(bool))
    of "integer": return SchemaValue(kind: SInteger, minVal: none(float), maxVal: none(float), exclusiveMin: none(float), exclusiveMax: none(float), multipleOf: none(float), enumValues: none(seq[float]), defaultValue: none(JsonNode), readOnly: none(bool), writeOnly: none(bool))
    of "boolean": return SchemaValue(kind: SBoolean, enumValues: none(seq[bool]), defaultValue: none(JsonNode), readOnly: none(bool), writeOnly: none(bool))
    of "null": return SchemaValue(kind: SNull, defaultValue: none(JsonNode), readOnly: none(bool), writeOnly: none(bool))
    else: raise newException(ValueError, "Unknown type: " & node.getStr())
  elif node.kind == JObject:
    if node.hasKey("const"):
      return SchemaValue(kind: SConst, value: node["const"])
    if node.hasKey("not"):
      return SchemaValue(kind: SNot, schema: parseSchema(node["not"]))
    if node.hasKey("anyOf"):
      if node["anyOf"].kind != JArray: raise newException(ValueError, "'anyOf' must be an array")
      var schemas: seq[SchemaValue] = @[]
      for s in node["anyOf"]: schemas.add(parseSchema(s))
      return SchemaValue(kind: SAnyOf, schemas: schemas)
    if node.hasKey("allOf"):
      if node["allOf"].kind != JArray: raise newException(ValueError, "'allOf' must be an array")
      var schemas: seq[SchemaValue] = @[]
      for s in node["allOf"]: schemas.add(parseSchema(s))
      return SchemaValue(kind: SAllOf, schemas: schemas)
    if node.hasKey("oneOf"):
      if node["oneOf"].kind != JArray: raise newException(ValueError, "'oneOf' must be an array")
      var schemas: seq[SchemaValue] = @[]
      for s in node["oneOf"]: schemas.add(parseSchema(s))
      return SchemaValue(kind: SOneOf, schemas: schemas)
    
    if node.hasKey("type"):
      let typeNode = node["type"]
      if typeNode.kind == JArray:
        var schemas: seq[SchemaValue] = @[]
        for t in typeNode:
          if t.kind == JString: schemas.add(parseSchema(JsonNode(kind: JString, val = t.getStr())))
          else: raise newException(ValueError, "Array elements in 'type' must be strings")
        return SchemaValue(kind: SAnyOf, schemas: schemas)
      if typeNode.kind == JString:
        let typeStr = typeNode.getStr()
        if typeStr != "object":
          var defVal = if node.hasKey("default") then some(node["default"]) else none(JsonNode)
          var ro = if node.hasKey("readOnly") and node["readOnly"].kind == JBool then some(node["readOnly"].getBool()) else none(bool)
          var wo = if node.hasKey("writeOnly") and node["writeOnly"].kind == JBool then some(node["writeOnly"].getBool()) else none(bool)
          case typeStr
          of "string":
            var minL = if node.hasKey("minLength") and node["minLength"].kind == JInt then some(node["minLength"].getInt()) else none(int)
            var maxL = if node.hasKey("maxLength") and node["maxLength"].kind == JInt then some(node["maxLength"].getInt()) else none(int)
            var enumV = none(seq[string])
            if node.hasKey("enum"):
              let enumNodes = parseEnum(node["enum"], SString).get()
              var values: seq[string] = @[]
              for e in enumNodes:
                if e.kind == JString: values.add(e.getStr())
                else: raise newException(ValueError, "Enum values for string type must be strings")
              enumV = some(values)
            var pat = if node.hasKey("pattern") and node["pattern"].kind == JString then some(node["pattern"].getStr()) else none(string)
            var fmt = if node.hasKey("format") and node["format"].kind == JString then some(node["format"].getStr()) else none(string)
            return SchemaValue(kind: SString, minLength: minL, maxLength: maxL, enumValues: enumV, pattern: pat, format: fmt, defaultValue: defVal, readOnly: ro, writeOnly: wo)
          of "number", "integer":
            let kind = if typeStr == "number" then SNumber else SInteger
            var minV = none(float)
            if node.hasKey("minimum"):
              let n = node["minimum"]
              if n.kind == JFloat: minV = some(n.getFloat())
              elif n.kind == JInt: minV = some(n.getInt().float)
              else: raise newException(ValueError, "'minimum' must be a number")
            var maxV = none(float)
            if node.hasKey("maximum"):
              let n = node["maximum"]
              if n.kind == JFloat: maxV = some(n.getFloat())
              elif n.kind == JInt: maxV = some(n.getInt().float)
              else: raise newException(ValueError, "'maximum' must be a number")
            var exMinV = none(float)
            if node.hasKey("exclusiveMinimum"):
              let n = node["exclusiveMinimum"]
              if n.kind == JFloat: exMinV = some(n.getFloat())
              elif n.kind == JInt: exMinV = some(n.getInt().float)
              else: raise newException(ValueError, "'exclusiveMinimum' must be a number")
            var exMaxV = none(float)
            if node.hasKey("exclusiveMaximum"):
              let n = node["exclusiveMaximum"]
              if n.kind == JFloat: exMaxV = some(n.getFloat())
              elif n.kind == JInt: exMaxV = some(n.getInt().float)
              else: raise newException(ValueError, "'exclusiveMaximum' must be a number")
            var multV = none(float)
            if node.hasKey("multipleOf"):
              let n = node["multipleOf"]
              if n.kind == JFloat: multV = some(n.getFloat())
              elif n.kind == JInt: multV = some(n.getInt().float)
              else: raise newException(ValueError, "'multipleOf' must be a number")
            var enumV = none(seq[float])
            if node.hasKey("enum"):
              let enumNodes = parseEnum(node["enum"], kind).get()
              var values: seq[float] = @[]
              for e in enumNodes:
                if e.kind == JFloat: values.add(e.getFloat())
                elif e.kind == JInt: values.add(e.getInt().float)
                else: raise newException(ValueError, "Enum values for number/integer type must be numbers")
              enumV = some(values)
            return SchemaValue(kind: kind, minVal: minV, maxVal: maxV, exclusiveMin: exMinV, exclusiveMax: exMaxV, multipleOf: multV, enumValues: enumV, defaultValue: defVal, readOnly: ro, writeOnly: wo)
          of "boolean": 
            var enumV = none(seq[bool])
            if node.hasKey("enum"):
              let enumNodes = parseEnum(node["enum"], SBoolean).get()
              var values: seq[bool] = @[]
              for e in enumNodes:
                if e.kind == JBool: values.add(e.getBool())
                else: raise newException(ValueError, "Enum values for boolean type must be booleans")
            enumV = some(values)
            return SchemaValue(kind: SBoolean, enumValues: enumV, defaultValue: defVal, readOnly: ro, writeOnly: wo)
          of "null":
            return SchemaValue(kind: SNull, defaultValue: defVal, readOnly: ro, writeOnly: wo)
          else: raise newException(ValueError, "Unknown type: " & typeStr)
      else: raise newException(ValueError, "'type' must be a string or an array of strings")
    
    # Object specific parsing (handles both explicit 'type: object' and implicit objects)
    var props = initTable[string, SchemaValue]()
    if node.hasKey("properties"):
      let propsNode = node["properties"]
      if propsNode.kind == JObject:
        for key, val in propsNode.fields: props[key] = parseSchema(val)

    var patProps = initTable[string, SchemaValue]()
    if node.hasKey("patternProperties"):
      let patPropsNode = node["patternProperties"]
      if patPropsNode.kind == JObject:
        for key, val in patPropsNode.fields: patProps[key] = parseSchema(val)

    var required: seq[string] = @[]
    if node.hasKey("required"):
      let reqsNode = node["required"]
      if reqsNode.kind == JArray:
        for item in reqsNode:
          if item.kind == JString: required.add(item.getStr())

    var addProps = none(bool)
    if node.hasKey("additionalProperties") and node["additionalProperties"].kind == JBool:
      addProps = some(node["additionalProperties"].getBool())

    var minProps = none(int)
    if node.hasKey("minProperties") and node["minProperties"].kind == JInt:
      minProps = some(node["minProperties"].getInt())

    var maxProps = none(int)
    if node.hasKey("maxProperties") and node["maxProperties"].kind == JInt:
      maxProps = some(node["maxProperties"].getInt())

    var deps = none(Table[string, Dependency])
    if node.hasKey("dependencies"):
      let depsNode = node["dependencies"]
      if depsNode.kind == JObject:
        var depsTable = initTable[string, Dependency]()
        for key, val in depsNode.fields:
          if val.kind == JArray:
            var targets: seq[string] = @[]
            for target in val:
              if target.kind == JString: targets.add(target.getStr())
            depsTable[key] = Dependency(kind: PropertyDeps, targets: targets)
          else:
            depsTable[key] = Dependency(kind: SchemaDep, schema: parseSchema(val))
        deps = some(depsTable)

    return SchemaValue(kind: SObject, properties: props, patternProperties: patProps, required: required, additionalProperties: addProps, minProperties: minProps, maxProperties: maxProps, dependencies: deps, defaultValue: if node.hasKey("default") then some(node["default"]) else none(JsonNode), readOnly: if node.hasKey("readOnly") and node["readOnly"].kind == JBool then some(node["readOnly"].getBool()) else none(bool), writeOnly: if node.hasKey("writeOnly") and node["writeOnly"].kind == JBool then some(node["writeOnly"].getBool()) else none(bool))

  elif node.kind == JArray:
    if node.len > 0:
      return SchemaValue(kind: SArray, items: ArrayItems(kind: Single, schema: parseSchema(node[0])), additionalItems: none(SchemaValue), minItems: none(int), maxItems: none(int), uniqueItems: none(bool), enumValues: none(seq[JsonNode]), defaultValue: none(JsonNode), readOnly: none(bool), writeOnly: none(bool))
    raise newException(ValueError, "Empty array in schema definition")

  raise newException(ValueError, "Invalid schema node")