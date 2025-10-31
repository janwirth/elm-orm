port module TestApp exposing (main)

import Json.Encode as Encode
import Platform



-- PORTS


port operations : { migrate : String, insert : String, query : String } -> Cmd msg


port operationsResult : (Encode.Value -> msg) -> Sub msg



-- MODEL


type alias Model =
    { results : List String
    , testStatus : TestStatus
    }


type TestStatus
    = NotStarted
    | MigrationsExecuted
    | InsertExecuted
    | QueryExecuted
    | TestsFailed String



-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( { results = [], testStatus = NotStarted }
    , operations
    )



-- UPDATE


type Msg
    = GotQueryResult Encode.Value
    | ExecuteNextTest


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotQueryResult _ ->
            ( { model | results = model.results ++ [ "Received result" ] }
            , Cmd.none
            )

        ExecuteNextTest ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    operationsResult GotQueryResult



-- MAIN


main : Program () Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }
