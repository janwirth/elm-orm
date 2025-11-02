port module Generator exposing (Model, Msg, main)

import Elm
import Elm.Annotation as Annotation
import Elm.Arg
import Elm.Op
import Elm.Op.Extra
import Elm.Parser
import Elm.Processing
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Node as Node exposing (Node(..))
import Elm.Syntax.TypeAlias exposing (TypeAlias)
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import Gen.Json.Decode as Decode
import Gen.Json.Decode.Pipeline as Pipeline
import Gen.String
import Gen.Time
import List.Extra
import Platform
import String.Extra



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
        typeDefinitions : List Elm.Declaration
        typeDefinitions =
            typeAliases
                |> List.map generateTypeDefinition

        queryFunctions : List Elm.Declaration
        queryFunctions =
            typeAliases
                |> List.concatMap generateQueryFunctions
    in
    (Elm.file [ "Generated", "Queries" ]
        (List.map Elm.expose (typeDefinitions ++ queryFunctions))
    ).contents


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


generateTypeDefinition : TypeAlias -> Elm.Declaration
generateTypeDefinition typeAlias =
    let
        fetchedTypeName =
            "Fetched" ++ Node.value typeAlias.name

        -- Dynamically generate fields based on the type alias
        fields =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition
                        |> List.map
                            (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                                let
                                    fieldAnnotation =
                                        case fieldType of
                                            Typed (Node _ ( _, "Bool" )) _ ->
                                                Annotation.bool

                                            Typed (Node _ ( _, "Int" )) _ ->
                                                Annotation.int

                                            _ ->
                                                Annotation.string
                                in
                                ( fieldName, fieldAnnotation )
                            )

                _ ->
                    []
    in
    Elm.alias fetchedTypeName
        (Annotation.record
            ([ ( "id", Annotation.int )
             , ( "createdAt", Gen.Time.annotation_.posix )
             , ( "updatedAt", Gen.Time.annotation_.posix )
             ]
                ++ fields
            )
        )


generateQueryFunctions : TypeAlias -> List Elm.Declaration
generateQueryFunctions typeAlias =
    let
        typeName : String
        typeName =
            Node.value typeAlias.name

        lowerTypeName : String
        lowerTypeName =
            String.Extra.decapitalize typeName

        pluralName : String
        pluralName =
            lowerTypeName ++ "s"

        fetchedTypeName : String
        fetchedTypeName =
            "Fetched" ++ typeName

        fields : Elm.Syntax.TypeAnnotation.RecordDefinition
        fields =
            case typeAlias.typeAnnotation of
                Node _ (Record recordDefinition) ->
                    recordDefinition

                _ ->
                    []

        -- Generate pipeline-style decoder fields
        pipelineDecoderFields : Elm.Expression -> Elm.Expression
        pipelineDecoderFields initial =
            List.foldl
                (\(Node _ ( Node _ fieldName, Node _ fieldType )) acc ->
                    let
                        decoderType : Elm.Expression
                        decoderType =
                            case fieldType of
                                Typed (Node _ ( _, "Bool" )) _ ->
                                    Decode.bool

                                Typed (Node _ ( _, "Int" )) _ ->
                                    Decode.int

                                _ ->
                                    Decode.string
                    in
                    acc
                        |> Elm.Op.Extra.pipe (Pipeline.required fieldName decoderType)
                )
                initial
                fields

        decodeTime : Elm.Expression
        decodeTime =
            Decode.map Gen.Time.call_.millisToPosix Decode.int

        decoder : Elm.Declaration
        decoder =
            Elm.declaration (lowerTypeName ++ "Decoder")
                (Decode.succeed (Elm.val fetchedTypeName)
                    |> Elm.Op.Extra.pipe (Pipeline.required "id" Decode.int)
                    |> Elm.Op.Extra.pipe (Pipeline.required "createdAt" decodeTime)
                    |> Elm.Op.Extra.pipe (Pipeline.required "updatedAt" decodeTime)
                    |> pipelineDecoderFields
                    |> Elm.withType (Decode.annotation_.decoder (Annotation.named [] fetchedTypeName))
                )

        createQueryImpl =
            case typeName of
                "User" ->
                    Elm.fn (Elm.Arg.varWith "user" (Annotation.named [] typeName))
                        (\user ->
                            insertQuery "users"
                                [ "name", "age" ]
                                [ user |> Elm.get "name"
                                , Gen.String.call_.fromInt (user |> Elm.get "age")
                                ]
                        )

                "Todo" ->
                    Elm.fn (Elm.Arg.varWith "todo" (Annotation.named [] typeName))
                        (\todo ->
                            insertQuery "todos"
                                [ "description", "completed" ]
                                [ todo |> Elm.get "description"
                                , Elm.ifThen (todo |> Elm.get "completed")
                                    (Elm.string "1")
                                    (Elm.string "0")
                                ]
                        )

                _ ->
                    Elm.fn (Elm.Arg.varWith lowerTypeName (Annotation.named [] typeName))
                        (\value ->
                            insertQuery pluralName
                                (generateInsertFields fields)
                                (generateInsertValues value fields)
                        )

        queries : List Elm.Declaration
        queries =
            [ Elm.declaration ("create" ++ typeName ++ "Query") createQueryImpl
            , Elm.declaration ("get" ++ typeName ++ "Query")
                (Elm.fn (Elm.Arg.var "id")
                    (\id ->
                        Elm.Op.append
                            (Elm.string ("SELECT * FROM " ++ pluralName ++ " WHERE id = "))
                            (Gen.String.call_.fromInt id)
                    )
                )
            , Elm.declaration ("getAll" ++ typeName ++ "sQuery")
                (Elm.string ("SELECT * FROM " ++ pluralName))
            , Elm.declaration ("delete" ++ typeName ++ "Query")
                (Elm.fn (Elm.Arg.var "id")
                    (\id ->
                        Elm.Op.append
                            (Elm.string ("DELETE FROM " ++ pluralName ++ " WHERE id = "))
                            (Gen.String.call_.fromInt id)
                    )
                )
            ]
    in
    decoder :: queries


insertQuery : String -> List String -> List Elm.Expression -> Elm.Expression
insertQuery table fields values =
    Elm.Op.Extra.concatStrings
        (Elm.string ("INSERT INTO " ++ table ++ " (" ++ String.join ", " fields ++ ") VALUES (\"")
            :: List.intersperse (Elm.string "\" , \"") values
            ++ [ Elm.string "\")" ]
        )


generateInsertFields : List (Node ( Node String, Node TypeAnnotation )) -> List String
generateInsertFields fields =
    fields
        |> List.map
            (\(Node _ ( Node _ fieldName, _ )) ->
                fieldName
            )


generateInsertValues : Elm.Expression -> List (Node ( Node String, Node TypeAnnotation )) -> List Elm.Expression
generateInsertValues recordName fields =
    fields
        |> List.map
            (\(Node _ ( Node _ fieldName, Node _ fieldType )) ->
                case fieldType of
                    Typed (Node _ ( _, "Int" )) _ ->
                        Gen.String.call_.fromInt (recordName |> Elm.get fieldName)

                    Typed (Node _ ( _, "Bool" )) _ ->
                        Elm.ifThen (recordName |> Elm.get fieldName)
                            (Elm.string "1")
                            (Elm.string "0")

                    _ ->
                        recordName |> Elm.get fieldName
            )


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
                |> List.Extra.removeWhen String.isEmpty
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
