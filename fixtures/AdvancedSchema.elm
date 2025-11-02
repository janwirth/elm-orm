module AdvancedSchema exposing (Application, BacklinkToUserDefinedTable(..), Dim1024(..), DynamicColumnDef(..), DynamicRow, DynamicValue, RankResult, Row, UserDefinedTable, decodeDynamicColumnDef, decodeDynamicRow, decodeDynamicValue, encodeDynamicColumnDef, encodeDynamicRow, encodeDynamicValue)

import Json.Decode as Decode
import Json.Encode as Encode
import Orm exposing (Multilink, Vector)


type Dim1024
    = Dim1024


type alias Application =
    { name : String
    , tables : Multilink UserDefinedTable -- create join table
    }


type alias UserDefinedTable =
    { name : String
    , columnDefs : List DynamicColumnDef
    , -- json type, gets encoded / decoded, just for user UI and dynamic data storage
      rows : Multilink Row
    }


type BacklinkToUserDefinedTable
    = Backlink UserDefinedTable


type alias Row =
    { backlink_ : BacklinkToUserDefinedTable
    , values : List DynamicValue
    , normalized : String
    , vector : Vector Dim1024
    }


type alias RankResult =
    { reference : DynamicRow
    , -- the one thing that many other results are ranked against
      subject : DynamicRow -- the item that has siblings which we rank against
    }



-- for this we need to provide codecs
--
-- [generator-start]


type DynamicColumnDef
    = DynamicColumnDef


type alias DynamicRow =
    { values : List DynamicValue }


type alias DynamicValue =
    Encode.Value



-- [generator-generated-start] -- DO NOT MODIFY or remove this line


decodeDynamicColumnDef =
    Decode.lazy
        (\_ ->
            decodeDynamicColumnDef
        )


decodeDynamicRow =
    Decode.map
        DynamicRow
        (Decode.field "values" (Decode.list decodeDynamicValue))


decodeDynamicValue =
    Decode.value


encodeDynamicColumnDef a =
    encodeDynamicColumnDef a


encodeDynamicRow a =
    Encode.object
        [ ( "values", Encode.list encodeDynamicValue a.values )
        ]


encodeDynamicValue a =
    a



-- [generator-end]
