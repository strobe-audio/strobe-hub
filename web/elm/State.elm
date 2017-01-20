module State exposing (..)

import Channel
import Receiver
import Rendition


type alias BroadcasterState =
    { channels : List Channel.State
    , receivers : List Receiver.State
    , renditions : List Rendition.State
    }


type alias VolumeChangeEvent =
    { id : String
    , target : String
    , volume : Float
    }


type ChannelListMode
    = LibraryMode
    | PlaylistMode
