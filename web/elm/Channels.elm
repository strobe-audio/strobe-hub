module Channels exposing (..)

import Channel
import ID
import Input
import Rendition
-- import Receivers


type alias Model =
    {}


type Msg
    = NoOp
      -- | VolumeChanged ( ID.Channel, Float )
    | AddRendition ( ID.Channel, Rendition.Model )
    | Modify ID.Channel Channel.Msg
    | ToggleSelector
    | ToggleAdd
    | Add String
    | AddInput Input.Msg
    | Added Channel.State
    | Choose Channel.Model



-- | ModifyReceivers Receivers.Msg


