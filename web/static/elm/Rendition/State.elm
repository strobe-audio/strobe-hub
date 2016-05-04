module Rendition.State (update) where

import Effects exposing (Effects, Never)
import Debug
import Rendition


update : Rendition.Action -> Rendition.Model -> ( Rendition.Model, Effects Rendition.Action )
update action rendition =
  case action of
    Rendition.NoOp ->
      ( rendition, Effects.none )

    Rendition.Skip ->
      ( rendition, Effects.none )

    Rendition.Progress event ->
      ( { rendition | playbackPosition = event.progress }, Effects.none )
