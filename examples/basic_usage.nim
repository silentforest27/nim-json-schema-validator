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
    \"score\": { \"type\": \"number\", \"multipleOf\": 0.5 }
  }
}")
let schema = parseSchema(schemaJson)

let validData = parseJson("{\"name\": \"Alice\", \"age\": 30, \"status\": \"active\", \"tags\": [\"nim\", \"coding\"], \"score\": 4.5}")
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