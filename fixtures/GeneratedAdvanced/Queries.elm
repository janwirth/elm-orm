module GeneratedAdvanced.Queries exposing (..)

import Json.Decode as Decode
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Time exposing (Posix)
import Time exposing (millisToPosix)
import AdvancedSchema exposing (..)

-- Fetched types with database fields

type alias FetchedApplication =
    { id : Int
    , createdAt : Posix
    , updatedAt : Posix
    , name : String
    }

type alias FetchedUserDefinedTable =
    { id : Int
    , createdAt : Posix
    , updatedAt : Posix
    , name : String
    , columnDefs : List DynamicColumnDef
    }

type alias FetchedRow =
    { id : Int
    , createdAt : Posix
    , updatedAt : Posix
    , userDefinedTableId : Int
    , values : List DynamicValue
    , normalized : String
    }

type alias FetchedRankResult =
    { id : Int
    , createdAt : Posix
    , updatedAt : Posix
    , reference : DynamicRow
    , subject : DynamicRow
    }

-- Decoders

applicationDecoder : Decode.Decoder FetchedApplication
applicationDecoder =
    Decode.succeed FetchedApplication
        |> required "id" Decode.int
        |> required "created_at" (Decode.string |> Decode.map (\str -> millisToPosix 0)) -- Placeholder for proper timestamp parsing
        |> required "updated_at" (Decode.string |> Decode.map (\str -> millisToPosix 0)) -- Placeholder for proper timestamp parsing
        |> required "name" Decode.string

userDefinedTableDecoder : Decode.Decoder FetchedUserDefinedTable
userDefinedTableDecoder =
    Decode.succeed FetchedUserDefinedTable
        |> required "id" Decode.int
        |> required "created_at" (Decode.string |> Decode.map (\str -> millisToPosix 0))
        |> required "updated_at" (Decode.string |> Decode.map (\str -> millisToPosix 0))
        |> required "name" Decode.string
        |> required "column_defs" (Decode.field "column_defs" (Decode.list decodeDynamicColumnDef))

rowDecoder : Decode.Decoder FetchedRow
rowDecoder =
    Decode.succeed FetchedRow
        |> required "id" Decode.int
        |> required "created_at" (Decode.string |> Decode.map (\str -> millisToPosix 0))
        |> required "updated_at" (Decode.string |> Decode.map (\str -> millisToPosix 0))
        |> required "user_defined_table_id" Decode.int
        |> required "values" (Decode.field "values" (Decode.list decodeDynamicValue))
        |> required "normalized" Decode.string

rankResultDecoder : Decode.Decoder FetchedRankResult
rankResultDecoder =
    Decode.succeed FetchedRankResult
        |> required "id" Decode.int
        |> required "created_at" (Decode.string |> Decode.map (\str -> millisToPosix 0))
        |> required "updated_at" (Decode.string |> Decode.map (\str -> millisToPosix 0))
        |> required "reference" (Decode.field "reference" decodeDynamicRow)
        |> required "subject" (Decode.field "subject" decodeDynamicRow)

-- Application Queries

createApplicationQuery : { name : String } -> String
createApplicationQuery app =
    "INSERT INTO application (name) VALUES ('" ++ app.name ++ "') RETURNING id"

getApplicationQuery : Int -> String
getApplicationQuery id =
    "SELECT * FROM application WHERE id = " ++ String.fromInt id

getAllApplicationsQuery : String
getAllApplicationsQuery =
    "SELECT * FROM application"

updateApplicationQuery : Int -> { name : String } -> String
updateApplicationQuery id app =
    "UPDATE application SET name = '" ++ app.name ++ "', updated_at = CURRENT_TIMESTAMP WHERE id = " ++ String.fromInt id

deleteApplicationQuery : Int -> String
deleteApplicationQuery id =
    "DELETE FROM application WHERE id = " ++ String.fromInt id

-- UserDefinedTable Queries

createUserDefinedTableQuery : { name : String, columnDefs : List DynamicColumnDef } -> String
createUserDefinedTableQuery table =
    "INSERT INTO user_defined_table (name, column_defs) VALUES ('" ++ table.name ++ "', '" ++ 
    Encode.encode 0 (Encode.list encodeDynamicColumnDef table.columnDefs) ++ "') RETURNING id"

getUserDefinedTableQuery : Int -> String
getUserDefinedTableQuery id =
    "SELECT * FROM user_defined_table WHERE id = " ++ String.fromInt id

getAllUserDefinedTablesQuery : String
getAllUserDefinedTablesQuery =
    "SELECT * FROM user_defined_table"

-- Row Queries

createRowQuery : { userDefinedTableId : Int, values : List DynamicValue, normalized : String } -> String
createRowQuery row =
    "INSERT INTO row (user_defined_table_id, values, normalized, vector_data) VALUES (" ++ 
    String.fromInt row.userDefinedTableId ++ ", '" ++
    Encode.encode 0 (Encode.list encodeDynamicValue row.values) ++ "', '" ++
    row.normalized ++ "', '[0,0,0,...,0]'::vector) RETURNING id"

getRowQuery : Int -> String
getRowQuery id =
    "SELECT * FROM row WHERE id = " ++ String.fromInt id

getRowsByTableQuery : Int -> String
getRowsByTableQuery tableId =
    "SELECT * FROM row WHERE user_defined_table_id = " ++ String.fromInt tableId

-- RankResult Queries

createRankResultQuery : { reference : DynamicRow, subject : DynamicRow } -> String
createRankResultQuery result =
    "INSERT INTO rank_result (reference, subject) VALUES ('" ++
    Encode.encode 0 (encodeDynamicRow result.reference) ++ "', '" ++
    Encode.encode 0 (encodeDynamicRow result.subject) ++ "') RETURNING id"

-- Join Table Queries

linkApplicationToTableQuery : Int -> Int -> String
linkApplicationToTableQuery appId tableId =
    "INSERT INTO application_user_defined_table (application_id, user_defined_table_id) VALUES (" ++
    String.fromInt appId ++ ", " ++ String.fromInt tableId ++ ")"

getTablesForApplicationQuery : Int -> String
getTablesForApplicationQuery appId =
    "SELECT t.* FROM user_defined_table t JOIN application_user_defined_table j ON t.id = j.user_defined_table_id WHERE j.application_id = " ++ String.fromInt appId

-- Vector Similarity Search Query

findSimilarRowsQuery : Int -> Int -> String
findSimilarRowsQuery rowId limit =
    "SELECT r.*, (r.vector_data <=> (SELECT vector_data FROM row WHERE id = " ++ String.fromInt rowId ++ ")) as distance " ++
    "FROM row r ORDER BY distance LIMIT " ++ String.fromInt limit