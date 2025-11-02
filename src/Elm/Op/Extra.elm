module Elm.Op.Extra exposing (concatStrings, pipe)

import Elm
import Elm.Op


pipe : (Elm.Expression -> Elm.Expression) -> Elm.Expression -> Elm.Expression
pipe f x =
    Elm.Op.pipe (Elm.functionReduced "x" f) x


concatStrings : List Elm.Expression -> Elm.Expression
concatStrings expr =
    case expr of
        [] ->
            Elm.string ""

        h :: t ->
            List.foldl (\e a -> Elm.Op.append a e) h t
