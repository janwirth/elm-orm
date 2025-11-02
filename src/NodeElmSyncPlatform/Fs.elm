module NodeElmSyncPlatform.Fs exposing (..)

import Json.Decode as Decode exposing        (Decoder)
import Json.Encode as Encode

type Method = ReadAllFilesInDirectory String

type alias FileWithContent = { absolutePath : String, content : String }
fileWithContentDecoder : Decoder FileWithContent
fileWithContentDecoder =
    Decode.map2 FileWithContent
        (Decode.field "absolutePath" Decode.string)
        (Decode.field "content" Decode.string)

readAllFilesInDirectory : String -> Result Decode.Error (List FileWithContent)
readAllFilesInDirectory relativePath =
    let
        interop = (Encode.object [])
        decoder = Decode.field "interop" (Decode.field "readAllFilesInDirectory" (Decode.field relativePath (Decode.list fileWithContentDecoder)))
    in
        Decode.decodeValue decoder interop

type Loadable a err = Loading | Loaded (List FileWithContent) | Error err

-- NOTES ON WATCHDIR: NOT POSSIBLE WITH SUBS, CAN ONLY USE POLLING ON LAMDERA LOCAL
-- when this is passed to runtime it will automatically start watching the directory and return the list of files
-- Server.watchDir "fixtures"
-- |> viewDirContents
-- where does the data come from?
-- server side does not have subs does it?
-- Nevermind
-- watchDir : String -> Loadable (List FileWithContent) Decode.Error
-- watchDir relativePath =
--     let
--         interop = (Encode.object [])
--         decoder = Decode.field "interop" (Decode.field "watchDir" (Decode.field relativePath (Decode.list fileWithContentDecoder)))
--     in
--         case Decode.decodeValue decoder interop of
--             Ok files ->
--                 Loaded files
--             Err error ->
--                 Error error

-- viewDirContents : Loadable (List FileWithContent) Decode.Error -> Html Msg
-- viewDirContents loadable =
--     case loadable of
--         Load ->
--             Html.text "Loading..."
--         Loaded files ->
--             Html.ul [] (List.map (\file -> Html.li [] [ Html.text file.absolutePath ]) files)
--         Error error ->
--             Html.text ("Error: " ++ error)
