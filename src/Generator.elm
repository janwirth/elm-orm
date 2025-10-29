port module Generator exposing (main)

import Elm.Parser
import Elm.Processing
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Node exposing (Node(..))
import Elm.Syntax.TypeAlias exposing (TypeAlias)
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..), RecordDefinition, RecordField)
import Json.Decode as Decode
import Json.Encode as Encode
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
    = NoOp


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
update msg model =
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
            "module Queries exposing (..)\n\nimport Json.Decode as Decode\nimport Json.Encode as Encode\nimport Time exposing (Posix)\n\n"

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
            "module Migrations exposing (..)\n\n"

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
    in
    "type alias " ++ fetchedTypeName ++ " =\n    { " ++ String.toLower typeName ++ " : " ++ typeName ++ "\n    , id : Int\n    , createdAt : Posix\n    , updatedAt : Posix\n    }"


generateQueryFunctions : TypeAlias -> String
generateQueryFunctions typeAlias =
    let
        typeName =
            typeAlias.name |> (\(Node _ name) -> name)

        lowerTypeName =
            String.toLower typeName

        pluralName =
            lowerTypeName ++ "s"

        decoder =
            lowerTypeName ++ "Decoder : Decode.Decoder " ++ typeName ++ "\n" ++ lowerTypeName ++ "Decoder =\n    Decode.succeed " ++ typeName ++ "\n        |> Decode.hardcoded 0  -- TODO: Generate proper decoder"

        encoder =
            lowerTypeName ++ "Encoder : " ++ typeName ++ " -> Encode.Value\n" ++ lowerTypeName ++ "Encoder " ++ lowerTypeName ++ " =\n    Encode.object []  -- TODO: Generate proper encoder"

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
    decoder ++ "\n\n" ++ encoder ++ "\n\n" ++ queries


extractFields : TypeAlias -> List String
extractFields typeAlias =
    case typeAlias.typeAnnotation of
        Node _ (Record recordDefinition) ->
            recordDefinition
                |> List.map (\(Node _ (field, _)) -> field |> (\(Node _ name) -> name))

        _ ->
            []


generateCreateTable : TypeAlias -> String
generateCreateTable typeAlias =
    let
        typeName =
            typeAlias.name |> (\(Node _ name) -> name)

        tableName =
            String.toLower typeName ++ "s"

        fields =
            extractFields typeAlias

        fieldColumns =
            fields
                |> List.map (\fieldName -> "        " ++ fieldName ++ " TEXT")
                |> String.join ",\n"

        allColumns =
            [ "        id INTEGER PRIMARY KEY AUTOINCREMENT"
            , fieldColumns
            , "        created_at DATETIME DEFAULT CURRENT_TIMESTAMP"
            , "        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP"
            ]
                |> List.filter (String.isEmpty >> not)
                |> String.join ",\n"

        createTableSql =
            [ tableName ++ "CreateTable : String"
            , tableName ++ "CreateTable ="
            , "    \"\"\"CREATE TABLE IF NOT EXISTS " ++ tableName ++ " ("
            , allColumns
            , "    )\"\"\""
            ]
                |> String.join "\n"
    in
    createTableSql