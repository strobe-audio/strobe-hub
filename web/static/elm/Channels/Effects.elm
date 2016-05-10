module Channels.Effects (..) where

import Effects exposing (Effects, Never)
import Channels
import Channels.Signals


addChannel : String -> Effects Channels.Action
addChannel channelName =
  let
    mailbox =
      Channels.Signals.addChannel
  in
    Signal.send mailbox.address channelName
      |> Effects.task
      |> Effects.map (always Channels.NoOp)
