module Root (..) where

import Dict exposing (Dict)
import Library
import Channel
import Receiver
import Rendition
import ID


type Action
  = InitialState BroadcasterState
  | ModifyChannel ID.Channel Channel.Action
  | ModifyReceiver ID.Receiver Receiver.Action
  | ReceiverStatus ( String, ReceiverStatusEvent )
    -- | ChannelStatus (String, ChannelStatusEvent)
    -- | UpdateReceiverVolume Receiver Float
    -- | UpdateChannelVolume Channel Float
    -- | TogglePlayPause (Channel, Bool)
  | VolumeChange VolumeChangeEvent
  | NewRendition Rendition.Model
    -- | PlaylistSkip PlaylistEntry
    -- | ShowAddReceiver ( Channel, Bool )
    -- | AttachReceiver Channel Receiver
  | LibraryRegistration Library.Node
  | Library Library.Action
  | SetListMode ChannelListMode
  | ToggleChannelSelector
  | ChooseChannel Channel.Model
  | Viewport Int
  | NoOp



-- would love to use these but it causes problems with ports


type alias Model =
  { channels : List Channel.Model
  , receivers : List Receiver.Model
  , showChannelSwitcher : Bool
  , activeChannelId : Maybe ID.Channel
  , listMode : ChannelListMode
  , mustShowLibrary : Bool
  , library : Library.Model
  }


type ChannelListMode
  = LibraryMode
  | PlaylistMode



-- { channels : List Channel
-- , receivers : List Receiver
-- , sources : List PlaylistEntry
-- , library : Library.Model
-- , ui : UIState
-- , activeChannelId: String
-- , activeState: String
-- }


type alias ChannelState =
  { id : String
  , name : String
  , position : Int
  , volume : Float
  , playing : Bool
  }


type alias BroadcasterState =
  { channels : List ChannelState
  , receivers : List ReceiverState
  , sources : List Rendition.Model
  }



-- type alias UIState =
--   { channels : List ChannelUIState
--   , receivers: List ReceiverUIState
--   }
-- type alias ChannelUIState =
--   { id: String
--   , showAddReceivers : Bool
--   , showRename : Bool
--   }
--
--
-- type alias ReceiverUIState =
--   { id: String
--   , showRename : Bool
--   }


type alias ReceiverState =
  { id : String
  , name : String
  , online : Bool
  , volume : Float
  , channelId : String
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


type alias SourceMetadata =
  { bit_rate : Maybe Int
  , channels : Maybe Int
  , duration_ms : Maybe Int
  , extension : Maybe String
  , filename : Maybe String
  , mime_type : Maybe String
  , sample_rate : Maybe Int
  , stream_size : Maybe Int
  , album : Maybe String
  , composer : Maybe String
  , date : Maybe String
  , disk_number : Maybe Int
  , disk_total : Maybe Int
  , genre : Maybe String
  , performer : Maybe String
  , title : Maybe String
  , track_number : Maybe Int
  , track_total : Maybe Int
  }


type alias Source =
  { id : String
  , metadata : SourceMetadata
  }


type alias PlaylistEntry =
  { id : String
  , position : Int
  , playbackPosition : Int
  , sourceId : String
  , channelId : String
  , source : Source
  }


type alias ChannelPlaylist =
  { active : Maybe PlaylistEntry
  , entries : List PlaylistEntry
  }


type alias ChannelContext =
  { receiverAddress : Receiver.Model -> Signal.Address Receiver.Action
  , channelAddress : Signal.Address Channel.Action
  , attached : List Receiver.Model
  , detached : List Receiver.Model
  }
