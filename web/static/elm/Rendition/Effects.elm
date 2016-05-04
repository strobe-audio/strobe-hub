module Rendition.Effects (..) where

import Effects exposing (Effects, Never)
import Rendition
import Rendition.Signals


skip : Rendition.Model -> Effects Rendition.Action
skip rendition =
  let
    mailbox =
      Rendition.Signals.skip
  in
    Signal.send mailbox.address ( rendition.zoneId, rendition.id )
      |> Effects.task
      |> Effects.map (always Rendition.NoOp)
