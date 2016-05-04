module Rendition.State (update) where

import Effects exposing (Effects, Never)
import Debug
import Rendition
import Rendition.Effects


update : Rendition.Action -> Rendition.Model -> ( Rendition.Model, Effects Rendition.Action )
update action rendition =
  case action of
    Rendition.NoOp ->
      ( rendition, Effects.none )

    Rendition.SkipTo ->
      ( rendition, Rendition.Effects.skip rendition )

    Rendition.Progress event ->
      ( { rendition | playbackPosition = event.progress }, Effects.none )
