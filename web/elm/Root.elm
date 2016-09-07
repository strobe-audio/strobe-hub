module Root exposing (..)

import Library
import Channel
import Channels
import Receiver
import Receivers
import Rendition
import ID
import Input
import Json.Decode as Json



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
