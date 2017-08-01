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
import Settings


type Msg
    = NoOp
    | Connected Bool
    | UrlChange Navigation.Location
    | Event (Result String State.Event)
    | SetListMode State.ChannelListMode
    | ActivateChannel Channel.Model
    | ToggleAddChannel
    | AddChannelInput Input.Msg
    | AddChannel String
    | Channel ID.Channel Channel.Msg
    | Receiver ID.Receiver Receiver.Msg
    | Library Library.Msg
    | SingleTouch (Utils.Touch.E Msg)
    | ActivateView State.ViewMode
    | ToggleShowChannelControl
    | ToggleShowHubControl
    | ActivateControlChannel
    | ActivateControlReceiver
    | SetConfigurationViewModel Settings.ViewMode
      -- application settings
    | LoadApplicationSettings String Settings.Model
    | UpdateApplicationSettings Settings.Field String
      -- events from broadcaster
    | BroadcasterLibraryRegistration Library.Section
      -- events from browser
    | BrowserViewport Int
    | BrowserScroll Int
    | AnimationScroll ( Time, Maybe Float, Float )
