module Rendition.State exposing (update)

import Debug
import Rendition
import Rendition.Cmd


update : Rendition.Msg -> Rendition.Model -> ( Rendition.Model, Cmd Rendition.Msg )
update action rendition =
    case action of
        Rendition.NoOp ->
            ( rendition, Cmd.none )

        Rendition.SkipTo ->
            ( rendition, Rendition.Cmd.skip rendition )

        Rendition.Progress event ->
            ( { rendition | playbackPosition = event.progress }, Cmd.none )

        Rendition.PlayPause ->
            ( rendition, Cmd.none )
