module Receiver exposing (..)

import ID
import Volume
import Input
import Utils.Touch


type alias Model =
    { id : ID.Receiver
    , name : String
    , online : Bool
    , volume : Float
    , channelId : ID.Channel
    , editName : Bool
    , editNameInput : Input.Model
    , touches : Utils.Touch.Model
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
    | ShowEditName Bool
    | EditName Input.Msg
    | Rename String
    | Renamed String
    | SingleTouch (Utils.Touch.E Msg)


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


attachedReceivers : List Model -> { a | id : ID.Channel } -> List Model
attachedReceivers receivers channel =
    attachedToChannel receivers channel


attachedToChannel : List Model -> { a | id : ID.Channel } -> List Model
attachedToChannel receivers channel =
    List.filter (\r -> r.channelId == channel.id) receivers


detachedReceivers : List Model -> { a | id : ID.Channel } -> List Model
detachedReceivers receivers channel =
    List.filter (\r -> r.channelId /= channel.id) receivers


onlineReceivers : List Model -> List Model
onlineReceivers receivers =
    List.filter .online receivers
