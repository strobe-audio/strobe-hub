module Msg exposing (..)

import Library
import Channels
import Receivers
import Rendition
import Root

type Msg
  = InitialState Root.BroadcasterState
  | VolumeChange Root.VolumeChangeEvent
  | NewRendition Rendition.Model
  | LibraryRegistration Library.Node
  | Library Library.Msg
  | SetListMode Root.ChannelListMode
  | Channels Channels.Msg
  | Receivers Receivers.Msg
  | Viewport Int
  | Scroll Int
  | NoOp

