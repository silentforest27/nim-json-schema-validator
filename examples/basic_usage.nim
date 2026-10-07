import std/json
import src/types, src/validator

let schemaJson = parseJson("{\"name\": \"string\", \"age\": \"number\", \"tags\": [\"string\"]}")
let schema = parseSchema(schemaJson)

let validData = parseJson("{\"name\": \"Alice\", \"age\": 30, \"tags\": [\"nim\", \"coding\"]}")
let invalidData = parseJson("{\"name\": \"Bob\", \"age\": \"thirty\", \"tags\": [\"rust\"]}")

let res1 = validate(validData, schema)
 echo "Valid data: ", res1.isValid # true

let res2 = validate(invalidData, schema)
 echo "Invalid data: ", res2.isValid, " Error: ", res2.error # false, Expected number