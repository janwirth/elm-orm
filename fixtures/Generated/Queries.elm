module Generated.Queries exposing (..)

import Json.Decode as Decode
import Time exposing (Posix)
import Time exposing (millisToPosix)

type alias FetchedUser =
    { id : Int
    , createdAt : Posix
    , updatedAt : Posix
    , age : Int
    , name : String
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
    Decode.map5 FetchedUser
        (Decode.field "id" Decode.int)
        (Decode.field "createdAt" Decode.int |> Decode.map millisToPosix)
        (Decode.field "updatedAt" Decode.int |> Decode.map millisToPosix)
        (Decode.field "age" Decode.int)
        (Decode.field "name" Decode.string)

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
    Decode.map5 FetchedTodo
        (Decode.field "description" Decode.string)
        (Decode.field "completed" Decode.bool)
        (Decode.field "id" Decode.int)
        (Decode.field "createdAt" Decode.int |> Decode.map millisToPosix)
        (Decode.field "updatedAt" Decode.int |> Decode.map millisToPosix)

createTodoQuery : String
createTodoQuery = "INSERT INTO todos DEFAULT VALUES"

getTodoQuery : Int -> String
getTodoQuery id = "SELECT * FROM todos WHERE id = " ++ String.fromInt id

getAllTodosQuery : String
getAllTodosQuery = "SELECT * FROM todos"

deleteTodoQuery : Int -> String
deleteTodoQuery id = "DELETE FROM todos WHERE id = " ++ String.fromInt id