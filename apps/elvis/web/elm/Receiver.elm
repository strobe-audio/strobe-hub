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
    , muted : Bool
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
    | Muted Bool
    | SingleTouch (Utils.Touch.E Msg)


type alias State =
    { id : String
    , name : String
    , online : Bool
    , volume : Float
    , muted : Bool
    , channelId : String
    }


sort : List Model -> List Model
sort receivers =
    List.sortBy (\r -> r.name) receivers


attachedReceivers : { a | id : ID.Channel } -> List Model -> List Model
attachedReceivers channel receivers =
    attachedToChannel channel receivers


attachedToChannel : { a | id : ID.Channel } -> List Model -> List Model
attachedToChannel channel receivers =
    List.filter (\r -> r.channelId == channel.id) receivers


detachedReceivers : { a | id : ID.Channel } -> List Model -> List Model
detachedReceivers channel receivers =
    List.filter (\r -> r.channelId /= channel.id) receivers


onlineReceivers : List Model -> List Model
onlineReceivers receivers =
    List.filter .online receivers


partitionReceivers : { a | id : ID.Channel } -> List Model -> ( List Model, List Model )
partitionReceivers channel receivers =
    List.partition (\r -> r.channelId == channel.id) receivers
