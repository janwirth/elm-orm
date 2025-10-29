module Generated.Queries exposing (..)

import Json.Decode as Decode
import Json.Decode.Pipeline exposing (required)
import Time exposing (Posix)
import Time exposing (millisToPosix)

type alias FetchedUser =
    { id : Int
    , createdAt : Posix
    , updatedAt : Posix
    , name : String
    , age : Int
    }

type alias FetchedTodo =
    { id : Int
    , createdAt : Posix
    , updatedAt : Posix
    , description : String
    , completed : Bool
    }

userDecoder : Decode.Decoder FetchedUser
userDecoder =
    Decode.succeed FetchedUser
        |> required "id" Decode.int
        |> required "createdAt" (Decode.int |> Decode.map millisToPosix)
        |> required "updatedAt" (Decode.int |> Decode.map millisToPosix)
        |> required "name" Decode.string
        |> required "age" Decode.int

createUserQuery : String
createUserQuery = "INSERT INTO users DEFAULT VALUES"

getUserQuery : Int -> String
getUserQuery id = "SELECT * FROM users WHERE id = " ++ String.fromInt id

getAllUsersQuery : String
getAllUsersQuery = "SELECT * FROM users"

deleteUserQuery : Int -> String
deleteUserQuery id = "DELETE FROM users WHERE id = " ++ String.fromInt id

todoDecoder : Decode.Decoder FetchedTodo
todoDecoder =
    Decode.succeed FetchedTodo
        |> required "id" Decode.int
        |> required "createdAt" (Decode.int |> Decode.map millisToPosix)
        |> required "updatedAt" (Decode.int |> Decode.map millisToPosix)
        |> required "description" Decode.string
        |> required "completed" Decode.bool

createTodoQuery : String
createTodoQuery = "INSERT INTO todos DEFAULT VALUES"

getTodoQuery : Int -> String
getTodoQuery id = "SELECT * FROM todos WHERE id = " ++ String.fromInt id

getAllTodosQuery : String
getAllTodosQuery = "SELECT * FROM todos"

deleteTodoQuery : Int -> String
deleteTodoQuery id = "DELETE FROM todos WHERE id = " ++ String.fromInt id