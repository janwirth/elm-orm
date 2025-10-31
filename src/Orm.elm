module Orm exposing (Backlink(..), Multilink(..), Vector(..))

-- WE are basically using opaque types as annotations
{--Makes an outbound link, registers join table in the database --}


type Multilink a
    = Multilink a


type Backlink a
    = Backlink { field : String }



{--This vector gets parsed
type Vector1024 = Dim1024 -> Vector (1024: Int) for the SQL generation
We do not support reading them for now (bc they are big and it eats up memory, so if it ends up on the client it gets slowww)
Only writing
--}


type Vector a
    = Vector a
