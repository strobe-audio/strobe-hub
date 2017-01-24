module Msg exposing (..)

import Time exposing (Time)
import Library
import Channel
import Receiver
import Rendition
import ID
import Input
import Navigation
import Utils.Touch
import State


type Msg
    = NoOp
    | Connected Bool
    | UrlChange Navigation.Location
    | InitialState State.BroadcasterState
    | SetListMode State.ChannelListMode
    | ActivateChannel Channel.Model
    | ToggleAddChannel
    | AddChannelInput Input.Msg
    | AddChannel String
    | Channel ID.Channel Channel.Msg
    | ShowAttachReceiver Bool
    | Receiver ID.Receiver Receiver.Msg
    | ReceiverPresence Receiver.State
    | Library Library.Msg
    | SingleTouch (Utils.Touch.E Msg)
    | ActivateView State.ViewMode
    | ToggleShowChannelControl
    | ReceiverAttachmentChange
      -- events from broadcaster
    | BroadcasterChannelAdded Channel.State
    | BroadcasterChannelRenamed ( ID.Channel, String )
    | BroadcasterReceiverRenamed ( ID.Receiver, String )
    | BroadcasterLibraryRegistration Library.Node
    | BroadcasterVolumeChange State.VolumeChangeEvent
    | BroadcasterRenditionAdded Rendition.State
      -- events from browser
    | BrowserViewport Int
    | BrowserScroll Int
    | AnimationScroll (Time, Float, Float)
