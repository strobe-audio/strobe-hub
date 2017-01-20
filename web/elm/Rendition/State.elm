module Rendition.State exposing (initialState, update)

import Debug
import Rendition
import Rendition.Cmd
import Utils.Touch


initialState : Rendition.State -> Rendition.Model
initialState state =
    { id = state.id
    , position = state.position
    , playbackPosition = state.playbackPosition
    , sourceId = state.sourceId
    , channelId = state.channelId
    , source = state.source
    , touches = Utils.Touch.emptyModel
    , swipe = Nothing
    , menu = False
    , removeInProgress = False
    }


update : Rendition.Msg -> Rendition.Model -> ( Rendition.Model, Cmd Rendition.Msg )
update action rendition =
    case action of
        Rendition.NoOp ->
            ( rendition, Cmd.none )

        Rendition.Remove ->
            ( { rendition | removeInProgress = True }, Rendition.Cmd.remove rendition )

        Rendition.SkipTo ->
            ( rendition, Rendition.Cmd.skip rendition )

        Rendition.CloseMenu ->
            ( { rendition | menu = False }, Cmd.none )

        Rendition.Progress event ->
            ( { rendition | playbackPosition = event.progress }, Cmd.none )

        Rendition.PlayPause ->
            ( rendition, Cmd.none )

        Rendition.Swipe te ->
            let
                touches =
                    Utils.Touch.update te rendition.touches

                ( updated, cmd ) =
                    case Utils.Touch.testEvent te touches of
                        Just (Utils.Touch.Swipe (Utils.Touch.Left) x msg) ->
                            { rendition | touches = touches, swipe = Just { offset = x } } ! []

                        Nothing ->
                            case rendition.swipe of
                                Just swipe ->
                                    { rendition | touches = touches, swipe = Nothing, menu = True } ! []

                                Nothing ->
                                    { rendition | touches = touches, menu = False } ! []

                        _ ->
                            { rendition | touches = touches, swipe = Nothing } ! []
            in
                updated ! []

        Rendition.Tap te ->
            let
                touches =
                    Debug.log "touches" (Utils.Touch.update te rendition.touches)

                ( updated, cmd ) =
                    case Utils.Touch.testEvent te touches of
                        Just (Utils.Touch.Tap msg) ->
                            update msg { rendition | touches = Utils.Touch.null }

                        _ ->
                            { rendition | touches = touches, swipe = Nothing } ! []
            in
                updated ! []
