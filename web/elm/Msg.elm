module Msg exposing (..)

import Library
import Channel
import Receiver
import Rendition
import Root
import ID
import Input


type Msg
    = NoOp
    | InitialState Root.BroadcasterState
    | ToggleChannelSelector
    -- | ChannelVolumeChange ( ID.Channel, Float )
    -- | RenditionVolumeChange ( ID.Channel, Float )
    | SetListMode Root.ChannelListMode
      -- | Channels Channels.Msg
    | ActivateChannel Channel.Model
    | ToggleAddChannel
    | AddChannelInput Input.Msg
    | AddChannel String
    | BroadcasterChannelAdded Channel.State
    | BroadcasterChannelRenamed (ID.Channel, String)
    | Channel ID.Channel Channel.Msg

    | ShowAttachReceiver Bool
    | Receiver ID.Receiver Receiver.Msg
    | Library Library.Msg
      -- | Receivers Receivers.Msg
      -- events from broadcaster
    | BroadcasterLibraryRegistration Library.Node
    | BroadcasterVolumeChange Root.VolumeChangeEvent
    | BroadcasterRenditionAdded Rendition.Model
      -- events from browser
    | BrowserViewport Int
    | BrowserScroll Int
