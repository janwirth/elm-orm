module TestApp exposing (main)

import Browser
import Html exposing (Html, div, text)
import Json.Encode as Encode
import Task
import Time
import Queries exposing (..)
import Migrations exposing (..)


-- PORTS
port executeMigration : String -> Cmd msg
port executeQuery : { query : String, params : List Encode.Value } -> Cmd msg
port queryResult : (Encode.Value -> msg) -> Sub msg


-- MODEL
type alias Model =
    { results : List String
    , testStatus : TestStatus
    }

type TestStatus
    = NotStarted
    | MigrationsExecuted
    | QueriesExecuted
    | TestsCompleted
    | TestsFailed String


-- INIT
init : () -> ( Model, Cmd Msg )
init _ =
    ( { results = [], testStatus = NotStarted }
    , executeMigration usersCreateTable
    )


-- UPDATE
type Msg
    = GotQueryResult Encode.Value
    | ExecuteNextTest
    | CurrentTime Time.Posix

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotQueryResult _ ->
            ( { model | results = model.results ++ [ "Received result" ] }
            , Task.perform CurrentTime Time.now
            )
        
        CurrentTime _ ->
            case model.testStatus of
                NotStarted ->
                    ( { model | testStatus = MigrationsExecuted }
                    , executeMigration todosCreateTable
                    )
                
                MigrationsExecuted ->
                    ( { model | testStatus = QueriesExecuted }
                    , Cmd.batch
                        [ executeQuery { query = createUserQuery, params = [] }
                        , executeQuery { query = createTodoQuery, params = [] }
                        ]
                    )
                
                QueriesExecuted ->
                    ( { model | testStatus = TestsCompleted }
                    , Cmd.batch
                        [ executeQuery { query = getAllUsersQuery, params = [] }
                        , executeQuery { query = getAllTodosQuery, params = [] }
                        ]
                    )
                
                TestsCompleted ->
                    ( model
                    , executeQuery 
                        { query = "SELECT 1"
                        , params = [ Encode.object [ ( "type", Encode.string "testComplete" ) ] ] 
                        }
                    )
                
                TestsFailed _ ->
                    ( model, Cmd.none )

        ExecuteNextTest ->
            case model.testStatus of
                NotStarted ->
                    ( { model | testStatus = MigrationsExecuted }
                    , executeMigration todosCreateTable
                    )
                
                _ ->
                    ( model, Cmd.none )


-- VIEW
view : Model -> Html Msg
view model =
    div []
        [ div [] [ text ("Test Status: " ++ testStatusToString model.testStatus) ]
        , div [] (List.map (\result -> div [] [ text result ]) model.results)
        ]

testStatusToString : TestStatus -> String
testStatusToString status =
    case status of
        NotStarted -> "Not Started"
        MigrationsExecuted -> "Migrations Executed"
        QueriesExecuted -> "Queries Executed"
        TestsCompleted -> "Tests Completed"
        TestsFailed error -> "Tests Failed: " ++ error


-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions _ =
    queryResult GotQueryResult


-- MAIN
main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
