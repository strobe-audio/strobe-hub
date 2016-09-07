module Channels exposing (..)

import Channel
import ID
import Input
import Rendition
import Receivers


type alias Model =
    { channels : List Channel.Model
    , showChannelSwitcher : Bool
    , activeChannelId : Maybe ID.Channel
    , showAddChannel : Bool
    , newChannelInput : Input.Model
    }


type Msg
    = NoOp
    | VolumeChanged ( ID.Channel, Float )
    | AddRendition ( ID.Channel, Rendition.Model )
    | Modify ID.Channel Channel.Msg
    | ToggleSelector
    | ToggleAdd
    | Add String
    | AddInput Input.Msg
    | Added Channel.State
    | Choose Channel.Model
    | ModifyReceivers Receivers.Msg


overlayActive : Model -> Bool
overlayActive channels =
    channels.showChannelSwitcher
