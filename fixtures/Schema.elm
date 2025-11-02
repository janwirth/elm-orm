module Schema exposing (Todo, User)

-- User-defined types


type alias User =
    { name : String
    , age : Int
    }


type alias Todo =
    { description : String
    , completed : Bool
    }
