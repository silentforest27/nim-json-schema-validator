import std/json
import src/types, src/validator

# Using the new explicit 'type' format
let schemaJson = parseJson("{
  \"type\": \"object\",
  \"properties\": {
    \"name\": { \"type\": \"string\" },
    \"age\": { \"type\": \"number\" },
    \"status\": { \"type\": \"string\", \"enum\": [\"active\", \"inactive\", \"pending\"] },
    \"tags\": {
      \"type\": \"array\",
      \"items\": { \"type\": \"string\" }
    }
  }
}")
let schema = parseSchema(schemaJson)

let validData = parseJson("{\"name\": \"Alice\", \"age\": 30, \"status\": \"active\", \"tags\": [\"nim\", \"coding\"]}")
let invalidData = parseJson("{\"name\": \"Bob\", \"age\": \"thirty\", \"status\": \"unknown\", \"tags\": [\"rust\"]}")

let res1 = validate(validData, schema)
 echo "Valid data: ", res1.isValid # true

let res2 = validate(invalidData, schema)
 echo "Invalid data: ", res2.isValid, " Error: ", res2.error # false, Property age: Expected number