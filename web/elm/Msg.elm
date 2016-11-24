module Msg exposing (..)

import Library
import Channel
import Receiver
import Rendition
import Root
import ID
import Input
import Navigation


type Msg
    = NoOp
    | UrlChange Navigation.Location
    | InitialState Root.BroadcasterState
    | ToggleChannelSelector
    | SetListMode Root.ChannelListMode
    | ActivateChannel Channel.Model
    | ToggleAddChannel
    | AddChannelInput Input.Msg
    | AddChannel String
    | Channel ID.Channel Channel.Msg
    | ShowAttachReceiver Bool
    | Receiver ID.Receiver Receiver.Msg
    | Library Library.Msg
      -- events from broadcaster
    | BroadcasterChannelAdded Channel.State
    | BroadcasterChannelRenamed ( ID.Channel, String )
    | BroadcasterReceiverRenamed ( ID.Receiver, String )
    | BroadcasterLibraryRegistration Library.Node
    | BroadcasterVolumeChange Root.VolumeChangeEvent
    | BroadcasterRenditionAdded Rendition.Model
      -- events from browser
    | BrowserViewport Int
    | BrowserScroll Int
