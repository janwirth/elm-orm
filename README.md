# Elm ORM

A code generator that creates type-safe Elm queries and migrations from your Elm schema definition.

## Installation

```bash
# Install globally
bun add -g @janwirth/elm-orm

# Or use directly with bun x
bun x @janwirth/elm-orm src/Schema.elm
```

## Usage

```bash
# Basic usage
elm-orm src/Schema.elm

# Specify output directory
elm-orm src/Schema.elm --output-dir ./src/Generated

# Get help
elm-orm --help
```

## Example

1. Create a schema file (e.g., `src/Schema.elm`):

```elm
module Schema exposing (..)


-- User-defined types
type alias User =
    { name : String
    , age: Int
    }


type alias Todo =
    { description : String
    , completed : Bool
    }
```

2. Generate the ORM files:

```bash
bun x @janwirth/elm-orm src/Schema.elm
```

3. This will create two files:

   - `Generated/Migrations.elm`: Contains SQL migration code
   - `Generated/Queries.elm`: Contains type-safe query builders

4. Import and use the generated files in your Elm application:

```elm
port module TestApp exposing (main)

import Browser
import Html exposing (Html, div, text)
import Json.Encode as Encode
import Task
import Time
import Generated.Queries exposing (..)
import Generated.Migrations exposing (..)


-- PORTS
port executeMigration : String -> Cmd msg
port executeQuery : { query : String, params : List Encode.Value } -> Cmd msg


-- INIT
init : () -> ( Model, Cmd Msg )
init _ =
    ( { results = [], testStatus = NotStarted }
    , executeMigration usersCreateTable
    )


-- Later in your update function
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- After migrations are executed
        MigrationsExecuted ->
            ( { model | testStatus = QueriesExecuted }
            , Cmd.batch
                [ executeQuery { query = createUserQuery, params = [] }
                , executeQuery { query = createTodoQuery, params = [] }
                ]
            )

        -- After queries are executed
        QueriesExecuted ->
            ( { model | testStatus = TestsCompleted }
            , Cmd.batch
                [ executeQuery { query = getAllUsersQuery, params = [] }
                , executeQuery { query = getAllTodosQuery, params = [] }
                ]
            )
```

## Features

- Type-safe query generation
- Automatic migration scripts
- Support for common data types (String, Int, Bool)
- Generated decoders for your types
- Standard CRUD operations

## Requirements

- Bun runtime
- Elm compiler

## License

MIT
