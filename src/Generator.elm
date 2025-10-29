port module Generator exposing (main)

import Elm.Parser
import Elm.Processing
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Node exposing (Node(..))
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
            "module Generated.Queries exposing (..)\n\nimport Json.Decode as Decode\nimport Time exposing (Posix)\nimport Time exposing (millisToPosix)\n\n"

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
        typeName =
            typeAlias.name |> (\(Node _ name) -> name)

        fetchedTypeName =
            "Fetched" ++ typeName
            
        fieldsList =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map 
                            (\(Node _ (field, _)) -> 
                                field |> (\(Node _ name) -> name)
                            )
                _ ->
                    []
                    
        -- Dynamically generate fields based on the type alias
        fieldsString =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map 
                            (\(Node _ (field, fieldType)) -> 
                                let
                                    fieldName = field |> (\(Node _ name) -> name)
                                    fieldTypeStr =
                                        case fieldType of
                                            Node _ (Typed (Node _ (_, "Bool")) _) -> "Bool"
                                            Node _ (Typed (Node _ (_, "Int")) _) -> "Int"
                                            _ -> "String"
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
            typeAlias.name |> (\(Node _ name) -> name)

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
                    (\(Node _ (field, fieldType)) -> 
                        let
                            fieldName = field |> (\(Node _ name) -> name)
                            decoderType =
                                case fieldType of
                                    Node _ (Typed (Node _ (_, "Bool")) _) -> "Decode.bool"
                                    Node _ (Typed (Node _ (_, "Int")) _) -> "Decode.int"
                                    _ -> "Decode.string"
                        in
                        "(Decode.field \"" ++ fieldName ++ "\" " ++ decoderType ++ ")"
                    )
                |> String.join "\n        "

        -- Count fields to determine the correct Decode.mapN function
        fieldCount = List.length fields + 3  -- +3 for id, createdAt, updatedAt
        
        mapFunction = "Decode.map" ++ String.fromInt fieldCount
        
        -- Built-in fields for every model
        builtInDecoderFields = 
            [ "(Decode.field \"id\" Decode.int)"
            , "(Decode.field \"createdAt\" Decode.int |> Decode.map millisToPosix)"
            , "(Decode.field \"updatedAt\" Decode.int |> Decode.map millisToPosix)"
            ]
        typeSpecificDecoderFields =(fields
                        |> List.map 
                            (\(Node _ (field, fieldType)) -> 
                                let
                                    fieldName = field |> (\(Node _ name) -> name)
                                    decoderType =
                                        case fieldType of
                                            Node _ (Typed (Node _ (_, "Bool")) _) -> "Decode.bool"
                                            Node _ (Typed (Node _ (_, "Int")) _) -> "Decode.int"
                                            _ -> "Decode.string"
                                in
                                "(Decode.field \"" ++ fieldName ++ "\" " ++ decoderType ++ ")"
                            )
                    )
            
        -- Combine built-in fields with custom fields
        allDecoderFields =
            List.append builtInDecoderFields typeSpecificDecoderFields
                    
                |> String.join "\n        "
                
        decoder =
            lowerTypeName ++ "Decoder : Decode.Decoder " ++ fetchedTypeName ++ "\n" ++ 
            lowerTypeName ++ "Decoder =\n    " ++ mapFunction ++ " " ++ fetchedTypeName ++ "\n        " ++ 
            allDecoderFields

        queries =
            [ "create" ++ typeName ++ "Query : String"
            , "create" ++ typeName ++ "Query = \"INSERT INTO " ++ pluralName ++ " DEFAULT VALUES\""
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




generateCreateTable : TypeAlias -> String
generateCreateTable typeAlias =
    let
        typeName =
            typeAlias.name |> (\(Node _ name) -> name)

        tableName =
            String.toLower typeName ++ "s"

        fieldColumns =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map 
                            (\(Node _ (field, fieldType)) -> 
                                let
                                    fieldName = field |> (\(Node _ name) -> name)
                                    sqlType =
                                        case fieldType of
                                            Node _ (Typed (Node _ (_, "Bool")) _) -> "BOOLEAN"
                                            Node _ (Typed (Node _ (_, "Int")) _) -> "INTEGER"
                                            _ -> "TEXT"
                                in
                                "        " ++ fieldName ++ " " ++ sqlType
                            )
                        |> String.join ",\n"
                _ ->
                    ""

        allColumns =
            [ "        id INTEGER PRIMARY KEY AUTOINCREMENT"
            , fieldColumns
            , "        created_at DATETIME DEFAULT CURRENT_TIMESTAMP"
            , "        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP"
            ]
                |> List.filter (String.isEmpty >> not)
                |> String.join ",\n"

        alterTableStatements =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map 
                            (\(Node _ (field, fieldType)) -> 
                                let
                                    fieldName = field |> (\(Node _ name) -> name)
                                    sqlType =
                                        case fieldType of
                                            Node _ (Typed (Node _ (_, "Bool")) _) -> "BOOLEAN"
                                            Node _ (Typed (Node _ (_, "Int")) _) -> "INTEGER"
                                            _ -> "TEXT"
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
            , "    );"
            , ""
            , alterTableStatements ++ "\"\"\""
            ]
                |> String.join "\n"
    in
    createTableSql