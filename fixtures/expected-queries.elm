module Queries exposing (..)

import Json.Decode as Decode
import Json.Encode as Encode
import Time exposing (Posix)

type alias FetchedUser =
    { user : User
    , id : Int
    , createdAt : Posix
    , updatedAt : Posix
    }

type alias FetchedTodo =
    { todo : Todo
    , id : Int
    , createdAt : Posix
    , updatedAt : Posix
    }

userDecoder : Decode.Decoder User
userDecoder =
    Decode.succeed User
        |> Decode.hardcoded 0  -- TODO: Generate proper decoder

userEncoder : User -> Encode.Value
userEncoder user =
    Encode.object []  -- TODO: Generate proper encoder

createUserQuery : String
createUserQuery = "INSERT INTO users DEFAULT VALUES"

getUserQuery : Int -> String
getUserQuery id = "SELECT * FROM users WHERE id = " ++ String.fromInt id

getAllUsersQuery : String
getAllUsersQuery = "SELECT * FROM users"

deleteUserQuery : Int -> String
deleteUserQuery id = "DELETE FROM users WHERE id = " ++ String.fromInt id

todoDecoder : Decode.Decoder Todo
todoDecoder =
    Decode.succeed Todo
        |> Decode.hardcoded 0  -- TODO: Generate proper decoder

todoEncoder : Todo -> Encode.Value
todoEncoder todo =
    Encode.object []  -- TODO: Generate proper encoder

createTodoQuery : String
createTodoQuery = "INSERT INTO todos DEFAULT VALUES"

getTodoQuery : Int -> String
getTodoQuery id = "SELECT * FROM todos WHERE id = " ++ String.fromInt id

getAllTodosQuery : String
getAllTodosQuery = "SELECT * FROM todos"

deleteTodoQuery : Int -> String
deleteTodoQuery id = "DELETE FROM todos WHERE id = " ++ String.fromInt id