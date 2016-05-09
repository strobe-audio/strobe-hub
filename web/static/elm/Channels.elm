module Channels (..) where

import Channel
import ID
import Input
import Rendition


type alias Model =
  { channels : List Channel.Model
  , showChannelSwitcher : Bool
  , activeChannelId : Maybe ID.Channel
  , showAddChannel : Bool
  , newChannelInput : Input.Model
  }


type Action
  = NoOp
  | VolumeChanged ( ID.Channel, Float )
  | AddRendition ( ID.Channel,  Rendition.Model )
  | Modify ID.Channel Channel.Action
  | ToggleSelector
  | ToggleAdd
  | Add String
  | NewInput Input.Action
  | Added Channel.State
  | Choose Channel.Model

type alias Context =
  { address : Signal.Address Action
  , modeAddress : Signal.Address () }
