module Receiver.Effects where

import Effects exposing (Effects, Never)

import Receiver
import Volume.Effects


volume : Receiver.Model -> Effects Receiver.Action
volume receiver =
  Volume.Effects.receiverVolumeChange receiver |> Effects.map (always Receiver.NoOp)
