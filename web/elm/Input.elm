module Input exposing (..)


type alias Model =
    { originalValue : String
    , value : String
    , validator : String -> Bool
    , autoCapitalize : String
    }


type Msg
    = NoOp
    | Update String
    | Cancel
    | Submit


type Action
    = Value String
    | Close
