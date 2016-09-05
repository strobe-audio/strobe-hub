module Root (..) where

import Library
import Channel
import Channels
import Receiver
import Receivers
import Rendition
import ID
import Input
import Json.Decode as Json


type Action
  = InitialState BroadcasterState
  | VolumeChange VolumeChangeEvent
  | NewRendition Rendition.Model
  | LibraryRegistration Library.Node
  | Library Library.Action
  | SetListMode ChannelListMode
  | Channels Channels.Action
  | Receivers Receivers.Action
  | Viewport Int
  | Scroll Int
  | NoOp


type alias Model =
  { channels : Channels.Model
  , receivers : Receivers.Model
  , listMode : ChannelListMode
  , showPlaylistAndLibrary : Bool
  , library : Library.Model
  }


type ChannelListMode
  = LibraryMode
  | PlaylistMode


type alias BroadcasterState =
  { channels : List Channel.State
  , receivers : List Receiver.State
  , sources : List Rendition.Model
  }


type alias ReceiverStatusEvent =
  { channelId : String
  , receiverId : String
  }


type alias ChannelStatusEvent =
  { channelId : String
  , status : String
  }


type alias VolumeChangeEvent =
  { id : String
  , target : String
  , volume : Float
  }


type alias ChannelContext =
  { receiverAddress : Receiver.Model -> Signal.Address Receiver.Action
  , channelAddress : Signal.Address Channel.Action
  , attached : List Receiver.Model
  , detached : List Receiver.Model
  }
