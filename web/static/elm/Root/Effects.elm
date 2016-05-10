module Root.Effects (..) where

import Effects exposing (Effects, Never)
import Root
import Root.Signals


addChannel : String -> Effects Root.Action
addChannel channelName =
  let
    mailbox =
      Root.Signals.addChannel
  in
    Signal.send mailbox.address channelName
      |> Effects.task
      |> Effects.map (always Root.NoOp)
