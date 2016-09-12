module Receiver exposing (..)

import ID
import Volume


type alias Model =
    { id : ID.Receiver
    , name : String
    , online : Bool
    , volume : Float
    , channelId : ID.Channel
    , editingName : Bool
    }


type Msg
    = NoOp
    | Volume Volume.Msg
    | VolumeChanged Float
    | Attach ID.Channel
    | Attached ID.Channel
    | Status String ID.Channel
    | Online ID.Channel
    | Offline


type alias State =
    { id : String
    , name : String
    , online : Bool
    , volume : Float
    , channelId : String
    }


sort : List Model -> List Model
sort receivers =
    List.sortBy (\r -> r.name) receivers
