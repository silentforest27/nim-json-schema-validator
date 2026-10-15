import std/json
import src/types, src/validator

# Using the new explicit 'type' format with a default value example
let schemaJson = parseJson("{
  \"type\": \"object\",
  \"properties\": {
    \"name\": { \"type\": \"string\", \"minLength\": 2, \"maxLength\": 10, \"default\": \"Unknown\" },
    \"age\": { \"type\": \"number\", \"minimum\": 0, \"maximum\": 120 },
    \"status\": { \"type\": \"string\", \"enum\": [\"active\", \"inactive\", \"pending\"] },
    \"tags\": {
      \"type\": \"array\",
      \"items\": { \"type\": \"string\" },
      \"minItems\": 1,
      \"maxItems\": 3,
      \"uniqueItems\": true
    },
    \"score\": { \"type\": \"number\", \"multipleOf\": 0.5 },
    \"email\": { \"type\": \"string\", \"format\": \"email\" },
    \"created_at\": { \"type\": \"string\", \"format\": \"date-time\" },
    \"username\": { \"type\": \"string\", \"pattern\": "^[a-z0-9_]+$" },
    \"middle_name\": { \"type\": [\"string\", \"null\"] }
  }
}")
let schema = parseSchema(schemaJson)

let validData = parseJson("{\"name\": \"Alice\", \"age\": 30, \"status\": \"active\", \"tags\": [\"nim\", \"coding\"], \"score\": 4.5, \"email\": \"alice@example.com\", \"created_at\": \"2023-10-27T10:00:00Z\", \"username\": \"alice_123\", \"middle_name\": null}")
let invalidData = parseJson("{\"name\": \"Bob\", \"age\": \"thirty\", \"status\": \"unknown\", \"tags\": [\"rust\"]}")
let invalidArrayData = parseJson("{\"name\": \"Charlie\", \"age\": 25, \"status\": \"active\", \"tags\": []}")
let tooManyTagsData = parseJson("{\"name\": \"Dave\", \"age\": 40, \"status\": \"active\", \"tags\": [\"a\", \"b\", \"c\", \"d\"]}")

# Boundary tests
let nameTooShort = parseJson("{\"name\": \"A\", \"age\": 20, \"status\": \"active\", \"tags\": [\"test\"]}")
let nameTooLong = parseJson("{\"name\": \"VeryLongNameIndeed\", \"age\": 20, \"status\": \"active\", \"tags\": [\"test\"]}")
let ageTooLow = parseJson("{\"name\": \"Alice\", \"age\": -1, \"status\": \"active\", \"tags\": [\"test\"]}")
let ageTooHigh = parseJson("{\"name\": \"Alice\", \"age\": 150, \"status\": \"active\", \"tags\": [\"test\"]}")

# multipleOf tests
let validScore = parseJson("{\"name\": \"Alice\", \"age\": 20, \"status\": \"active\", \"tags\": [\"test\"], \"score\": 5.0}")
let invalidScore = parseJson("{\"name\": \"Alice\", \"age\": 20, \"status\": \"active\", \"tags\": [\"test\"], \"score\": 5.2}")

# uniqueItems tests
let duplicateTagsData = parseJson("{\"name\": \"Eve\", \"age\": 22, \"status\": \"active\", \"tags\": [\"nim\", \"nim\"]}")

# Format tests
let invalidEmail = parseJson("{\"email\": \"not-an-email\"}")
let invalidDate = parseJson("{\"created_at\": \"2023-13-45\"}")

# Pattern tests
let validUsername = parseJson("{\"username\": \"valid_user123\"}")
let invalidUsername = parseJson("{\"username\": \"Invalid-User!\"}")

let res1 = validate(validData, schema)
 echo "Valid data: ", res1.isValid # true

let res2 = validate(invalidData, schema)
 echo "Invalid data: ", res2.isValid, " Error: ", res2.error # false, Property age: Expected number

let res3 = validate(invalidArrayData, schema)
 echo "Invalid array (too short): ", res3.isValid, " Error: ", res3.error # false, Property tags: Array length 0 is less than minimum 1

let res4 = validate(tooManyTagsData, schema)
 echo "Invalid array (too long): ", res4.isValid, " Error: ", res4.error # false, Property tags: Array length 4 is greater than maximum 3

let res5 = validate(nameTooShort, schema)
 echo "Name too short: ", res5.isValid, " Error: ", res5.error

let res6 = validate(nameTooLong, schema)
 echo "Name too long: ", res6.isValid, " Error: ", res6.error

let res7 = validate(ageTooLow, schema)
 echo "Age too low: ", res7.isValid, " Error: ", res7.error

let res8 = validate(ageTooHigh, schema)
 echo "Age too high: ", res8.isValid, " Error: ", res8.error

let res9 = validate(validScore, schema)
 echo "Valid score (multipleOf): ", res9.isValid

let res10 = validate(invalidScore, schema)
 echo "Invalid score (multipleOf): ", res10.isValid, " Error: ", res10.error

let res11 = validate(duplicateTagsData, schema)
 echo "Duplicate tags (uniqueItems): ", res11.isValid, " Error: ", res11.error

let res12 = validate(invalidEmail, schema)
 echo "Invalid email: ", res12.isValid, " Error: ", res12.error

let res13 = validate(invalidDate, schema)
 echo "Invalid date: ", res13.isValid, " Error: ", res13.error

let res14 = validate(validUsername, schema)
 echo "Valid username (pattern): ", res14.isValid

let res15 = validate(invalidUsername, schema)
 echo "Invalid username (pattern): ", res15.isValid, " Error: ", res15.error

# Dependency tests
let depSchemaJson = parseJson("{
  \"type\": \"object\",
  \"dependencies\": {
    \"credit_card\": { \"required\": [\"billing_address\"] },
    \"billing_address\": { \"type\": \"object\", \"properties\": { \"city\": { \"type\": \"string\" } }, \"required\": [\"city\"] }
  }
}")
let depSchema = parseSchema(depSchemaJson)

let validDep = parseJson("{\"credit_card\": true, \"billing_address\": {\"city\": \"New York\"}}")
let invalidPropDep = parseJson("{\"credit_card\": true}")
let invalidSchemaDep = parseJson("{\"billing_address\": {\"zip\": 10001}}")

 echo "Valid dependency: ", validate(validDep, depSchema).isValid
 echo "Invalid property dependency: ", validate(invalidPropDep, depSchema).isValid
 echo "Invalid schema dependency: ", validate(invalidSchemaDep, depSchema).isValid

# Const test
let constSchema = parseSchema(parseJson("{\"const\": 42}"))
 echo "Valid const: ", validate(parseJson("42"), constSchema).isValid
 echo "Invalid const: ", validate(parseJson("43"), constSchema).isValid

# Required properties test
let reqSchema = parseSchema(parseJson("{\"type\": \"object\", \"required\": [\"id\", \"email\"]}"))
let reqValid = parseJson("{\"id\": 1, \"email\": \"test@test.com\"}")
let reqInvalid = parseJson("{\"id\": 1}")
 echo "Required valid: ", validate(reqValid, reqSchema).isValid
 echo "Required invalid: ", validate(reqInvalid, reqSchema).isValid, " Error: ", validate(reqInvalid, reqSchema).error

# Null tests
let nullSchema = parseSchema(parseJson("{\"type\": \"null\"}"))
 echo "Valid null: ", validate(parseJson("null"), nullSchema).isValid
 echo "Invalid null: ", validate(parseJson("42"), nullSchema).isValid

# Exclusive bounds tests
let exclSchema = parseSchema(parseJson("{\"type\": \"number\", \"exclusiveMinimum\": 10, \"exclusiveMaximum\": 20}"))
 echo "Exclusive valid (15): ", validate(parseJson("15"), exclSchema).isValid
 echo "Exclusive invalid (10): ", validate(parseJson("10"), exclSchema).isValid
 echo "Exclusive invalid (20): ", validate(parseJson("20"), exclSchema).isValid

# PropertyNames tests
let propNamesSchema = parseSchema(parseJson("{\"type\": \"object\", \"propertyNames\": {\"pattern\": "^prop_"}}"))
let validPropNames = parseJson("{\"prop_1\": 1, \"prop_2\": 2}")
let invalidPropNames = parseJson("{\"valid_1\": 1}")
 echo "Valid property names: ", validate(validPropNames, propNamesSchema).isValid
 echo "Invalid property names: ", validate(invalidPropNames, propNamesSchema).isValid, " Error: ", validate(invalidPropNames, propNamesSchema).error

# Default values test
let defaultData = parseJson("{\"age\": 25, \"status\": \"active\", \"tags\": [\"test\"]}")
var mutableData = defaultData
fillDefaults(mutableData, schema)
 echo "Filled default name: ", mutableData["name"].getStr() # Expected: Unknown