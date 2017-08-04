module Volume exposing (..)


type Msg
    = Change Bool (Maybe Float)
    | ToggleMute
