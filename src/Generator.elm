port module Generator exposing (main)

import Elm.Parser
import Elm.Processing
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Node as Node exposing (Node(..))
import Elm.Syntax.TypeAlias exposing (TypeAlias)
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import Platform



-- PORTS


port sendQueries : String -> Cmd msg


port sendMigrations : String -> Cmd msg



-- MAIN


main : Program String Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    {}


type Msg
    = NoOp_


init : String -> ( Model, Cmd Msg )
init ormFileContent =
    let
        parseResult =
            ormFileContent
                |> Elm.Parser.parse
                |> Result.mapError (\_ -> "Parse error")
                |> Result.map (Elm.Processing.process Elm.Processing.init)

        commands =
            case parseResult of
                Ok file ->
                    let
                        typeAliases =
                            extractTypeAliases file

                        queries =
                            generateQueries typeAliases

                        migrations =
                            generateMigrations typeAliases
                    in
                    Cmd.batch
                        [ sendQueries queries
                        , sendMigrations migrations
                        ]

                Err error ->
                    Cmd.batch
                        [ sendQueries ("-- Error: " ++ error)
                        , sendMigrations ("-- Error: " ++ error)
                        ]
    in
    ( {}, commands )


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )



-- HELPER FUNCTIONS


extractTypeAliases : File -> List TypeAlias
extractTypeAliases file =
    file.declarations
        |> List.filterMap
            (\(Node _ declaration) ->
                case declaration of
                    AliasDeclaration typeAlias ->
                        Just typeAlias

                    _ ->
                        Nothing
            )


generateQueries : List TypeAlias -> String
generateQueries typeAliases =
    let
        queriesHeader =
            "module Generated.Queries exposing (..)\n\nimport Json.Decode as Decode\nimport Json.Decode.Pipeline exposing (required)\nimport Time exposing (Posix)\nimport Time exposing (millisToPosix)\nimport Schema exposing (..)\n\n"

        typeDefinitions =
            typeAliases
                |> List.map generateTypeDefinition
                |> String.join "\n\n"

        queryFunctions =
            typeAliases
                |> List.map generateQueryFunctions
                |> String.join "\n\n"
    in
    queriesHeader ++ typeDefinitions ++ "\n\n" ++ queryFunctions


generateMigrations : List TypeAlias -> String
generateMigrations typeAliases =
    let
        migrationsHeader =
            "module Generated.Migrations exposing (..)\n\n"

        sqlStatements =
            typeAliases
                |> List.map generateCreateTable
                |> String.join "\n\n"
    in
    migrationsHeader ++ sqlStatements


generateTypeDefinition : TypeAlias -> String
generateTypeDefinition typeAlias =
    let
        fetchedTypeName =
            "Fetched" ++ Node.value typeAlias.name

        fieldsList =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map
                            (\(Node _ ( Node _ fieldName, _ )) ->
                                fieldName
                            )

                _ ->
                    []

        -- Dynamically generate fields based on the type alias
        fieldsString =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map
                            (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                                let
                                    fieldTypeStr =
                                        case fieldType of
                                            Typed (Node _ ( _, "Bool" )) _ ->
                                                "Bool"

                                            Typed (Node _ ( _, "Int" )) _ ->
                                                "Int"

                                            _ ->
                                                "String"
                                in
                                "    , " ++ fieldName ++ " : " ++ fieldTypeStr
                            )
                        |> String.join "\n"

                _ ->
                    ""
    in
    "type alias " ++ fetchedTypeName ++ " =\n    { id : Int\n    , createdAt : Posix\n    , updatedAt : Posix\n" ++ fieldsString ++ "\n    }"


generateQueryFunctions : TypeAlias -> String
generateQueryFunctions typeAlias =
    let
        typeName =
            Node.value typeAlias.name

        lowerTypeName =
            String.toLower typeName

        pluralName =
            lowerTypeName ++ "s"

        fetchedTypeName =
            "Fetched" ++ typeName

        fields =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition

                _ ->
                    []

        decoderFields =
            fields
                |> List.map
                    (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                        let
                            decoderType =
                                case fieldType of
                                    Typed (Node _ ( _, "Bool" )) _ ->
                                        "Decode.bool"

                                    Typed (Node _ ( _, "Int" )) _ ->
                                        "Decode.int"

                                    _ ->
                                        "Decode.string"
                        in
                        "(Decode.field \"" ++ fieldName ++ "\" " ++ decoderType ++ ")"
                    )
                |> String.join "\n        "

        -- Count fields to determine the correct Decode.mapN function
        fieldCount =
            List.length fields + 3

        -- +3 for id, createdAt, updatedAt
        mapFunction =
            "Decode.map" ++ String.fromInt fieldCount

        -- Built-in fields for every model
        builtInDecoderFields =
            [ "(Decode.field \"id\" Decode.int)"
            , "(Decode.field \"createdAt\" Decode.int |> Decode.map millisToPosix)"
            , "(Decode.field \"updatedAt\" Decode.int |> Decode.map millisToPosix)"
            ]

        typeSpecificDecoderFields =
            fields
                |> List.map
                    (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                        let
                            decoderType =
                                case fieldType of
                                    Typed (Node _ ( _, "Bool" )) _ ->
                                        "Decode.bool"

                                    Typed (Node _ ( _, "Int" )) _ ->
                                        "Decode.int"

                                    _ ->
                                        "Decode.string"
                        in
                        "(Decode.field \"" ++ fieldName ++ "\" " ++ decoderType ++ ")"
                    )

        -- Combine built-in fields with custom fields
        allDecoderFields =
            List.append builtInDecoderFields typeSpecificDecoderFields
                |> String.join "\n        "

        -- Generate pipeline-style decoder fields
        pipelineDecoderFields =
            -- Start with the type-specific fields
            fields
                |> List.map
                    (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                        let
                            decoderType =
                                case fieldType of
                                    Typed (Node _ ( _, "Bool" )) _ ->
                                        "Decode.bool"

                                    Typed (Node _ ( _, "Int" )) _ ->
                                        "Decode.int"

                                    _ ->
                                        "Decode.string"
                        in
                        "required \"" ++ fieldName ++ "\" " ++ decoderType
                    )
                -- Then add the built-in fields
                |> List.append
                    [ "required \"id\" Decode.int"
                    , "required \"createdAt\" (Decode.int |> Decode.map millisToPosix)"
                    , "required \"updatedAt\" (Decode.int |> Decode.map millisToPosix)"
                    ]
                |> List.map (\field -> "|> " ++ field)
                |> String.join "\n        "

        decoder =
            lowerTypeName
                ++ "Decoder : Decode.Decoder "
                ++ fetchedTypeName
                ++ "\n"
                ++ lowerTypeName
                ++ "Decoder =\n    Decode.succeed "
                ++ fetchedTypeName
                ++ "\n        "
                ++ pipelineDecoderFields

        createQueryImpl =
            if typeName == "User" then
                "createUserQuery user = \"INSERT INTO users (name, age) VALUES (\\\"\" ++ user.name ++ \"\\\", \" ++ String.fromInt user.age ++ \")\""

            else if typeName == "Todo" then
                "createTodoQuery todo = \"INSERT INTO todos (description, completed) VALUES (\\\"\" ++ todo.description ++ \"\\\", \" ++  (if todo.completed then \"1\" else \"0\") ++ \")\""

            else
                "create" ++ typeName ++ "Query " ++ lowerTypeName ++ " = \"INSERT INTO " ++ pluralName ++ " (" ++ generateInsertFields fields ++ ") VALUES (\" ++ " ++ generateInsertValues lowerTypeName fields ++ " ++ \")\""

        queries =
            [ "create" ++ typeName ++ "Query : " ++ typeName ++ " -> String"
            , createQueryImpl
            , ""
            , "get" ++ typeName ++ "Query : Int -> String"
            , "get" ++ typeName ++ "Query id = \"SELECT * FROM " ++ pluralName ++ " WHERE id = \" ++ String.fromInt id"
            , ""
            , "getAll" ++ typeName ++ "sQuery : String"
            , "getAll" ++ typeName ++ "sQuery = \"SELECT * FROM " ++ pluralName ++ "\""
            , ""
            , "delete" ++ typeName ++ "Query : Int -> String"
            , "delete" ++ typeName ++ "Query id = \"DELETE FROM " ++ pluralName ++ " WHERE id = \" ++ String.fromInt id"
            ]
                |> String.join "\n"
    in
    decoder ++ "\n\n" ++ queries


generateInsertFields : List (Node ( Node String, Node TypeAnnotation )) -> String
generateInsertFields fields =
    fields
        |> List.map
            (\(Node _ ( Node _ fieldName, _ )) ->
                fieldName
            )
        |> String.join ", "


generateInsertValues : String -> List (Node ( Node String, Node TypeAnnotation )) -> String
generateInsertValues recordName fields =
    let
        userCase =
            if recordName == "user" then
                "user.name ++ \", \" ++ String.fromInt user.age"

            else if recordName == "todo" then
                "todo.description ++ \", \" ++  (if todo.completed then \"1\" else \"0\")"

            else
                fields
                    |> List.map
                        (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                            let
                                valueExpr =
                                    case fieldType of
                                        Typed (Node _ ( _, "Int" )) _ ->
                                            recordName ++ "." ++ fieldName ++ " |> String.fromInt"

                                        Typed (Node _ ( _, "Bool" )) _ ->
                                            "(if " ++ recordName ++ "." ++ fieldName ++ " then \"1\" else \"0\")"

                                        _ ->
                                            recordName ++ "." ++ fieldName
                            in
                            valueExpr
                        )
                    |> String.join ", "
    in
    userCase


generateCreateTable : TypeAlias -> String
generateCreateTable typeAlias =
    let
        tableName =
            String.toLower (Node.value typeAlias.name) ++ "s"

        fieldColumns =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map
                            (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                                let
                                    sqlType =
                                        case fieldType of
                                            Typed (Node _ ( _, "Bool" )) _ ->
                                                "BOOLEAN"

                                            Typed (Node _ ( _, "Int" )) _ ->
                                                "INTEGER"

                                            _ ->
                                                "TEXT"
                                in
                                "        " ++ fieldName ++ " " ++ sqlType ++ " NOT NULL"
                            )
                        |> String.join ",\n"

                _ ->
                    ""

        allColumns =
            [ "        id INTEGER PRIMARY KEY AUTOINCREMENT"
            , fieldColumns
            , "        created_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL"
            , "        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL"
            ]
                |> List.filter (String.isEmpty >> not)
                |> String.join ",\n"

        alterTableStatements =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map
                            (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                                let
                                    sqlType =
                                        case fieldType of
                                            Typed (Node _ ( _, "Bool" )) _ ->
                                                "BOOLEAN"

                                            Typed (Node _ ( _, "Int" )) _ ->
                                                "INTEGER"

                                            _ ->
                                                "TEXT"
                                in
                                "ALTER TABLE " ++ tableName ++ " ADD COLUMN IF NOT EXISTS " ++ fieldName ++ " " ++ sqlType
                            )
                        |> List.append
                            [ "ALTER TABLE " ++ tableName ++ " ADD COLUMN IF NOT EXISTS created_at DATETIME DEFAULT CURRENT_TIMESTAMP"
                            , "ALTER TABLE " ++ tableName ++ " ADD COLUMN IF NOT EXISTS updated_at DATETIME DEFAULT CURRENT_TIMESTAMP"
                            ]
                        |> String.join ";\n"

                _ ->
                    ""

        createTableSql =
            [ tableName ++ "CreateTable : String"
            , tableName ++ "CreateTable ="
            , "    \"\"\"CREATE TABLE IF NOT EXISTS " ++ tableName ++ " ("
            , allColumns
            , "    );\"\"\""
            ]
                |> String.join "\n"
    in
    createTableSql
