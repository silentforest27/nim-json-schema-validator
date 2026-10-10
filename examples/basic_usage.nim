import std/json
import src/types, src/validator

# Using the new explicit 'type' format with a default value example
let schemaJson = parseJson("{
  \"type\": \"object\",
  \"properties\": {
    \"name\": { \"type\": \"string\", \"default\": \"Unknown\" },
    \"age\": { \"type\": \"number\" },
    \"status\": { \"type\": \"string\", \"enum\": [\"active\", \"inactive\", \"pending\"] },
    \"tags\": {
      \"type\": \"array\",
      \"items\": { \"type\": \"string\" },
      \"minItems\": 1,
      \"maxItems\": 3
    }
  }
}")
let schema = parseSchema(schemaJson)

let validData = parseJson("{\"name\": \"Alice\", \"age\": 30, \"status\": \"active\", \"tags\": [\"nim\", \"coding\"]}")
let invalidData = parseJson("{\"name\": \"Bob\", \"age\": \"thirty\", \"status\": \"unknown\", \"tags\": [\"rust\"]}")
let invalidArrayData = parseJson("{\"name\": \"Charlie\", \"age\": 25, \"status\": \"active\", \"tags\": []}")
let tooManyTagsData = parseJson("{\"name\": \"Dave\", \"age\": 40, \"status\": \"active\", \"tags\": [\"a\", \"b\", \"c\", \"d\"]}")

let res1 = validate(validData, schema)
 echo "Valid data: ", res1.isValid # true

let res2 = validate(invalidData, schema)
 echo "Invalid data: ", res2.isValid, " Error: ", res2.error # false, Property age: Expected number

let res3 = validate(invalidArrayData, schema)
 echo "Invalid array (too short): ", res3.isValid, " Error: ", res3.error # false, Property tags: Array length 0 is less than minimum 1

let res4 = validate(tooManyTagsData, schema)
 echo "Invalid array (too long): ", res4.isValid, " Error: ", res4.error # false, Property tags: Array length 4 is greater than maximum 3