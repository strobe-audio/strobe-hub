module Receiver.Effects (..) where

import Effects exposing (Effects, Never)
import ID
import Receiver
import Receiver.Signals
import Volume.Effects


volume : Receiver.Model -> Effects Receiver.Action
volume receiver =
  Volume.Effects.receiverVolumeChange receiver |> Effects.map (always Receiver.NoOp)


attach : ID.Channel -> ID.Receiver -> Effects Receiver.Action
attach channelId receiverId =
  let
    mailbox =
      Receiver.Signals.attach
  in
    Signal.send mailbox.address ( channelId, receiverId )
      |> Effects.task
      |> Effects.map (always Receiver.NoOp)
