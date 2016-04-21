module View (root) where


import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import Types exposing (..)
import State
import Channel.View
import Channel

root : Signal.Address Action -> Model -> Html
root address model =
  let
      activeChannel = State.activeChannel model
  in
    case activeChannel of
      Nothing ->
        div [] [ text "NO ACTIVE CHANNEL" ]
      Just channel ->
        activeChannelView address model channel

activeChannelView : Signal.Address Action -> Model -> Channel.Model -> Html
activeChannelView address model channel =
  let
      channelAddress = Signal.forwardTo address (ModifyChannel channel)
  -- div [ classList [("elvis", True), ("elvis-mode-channel", model.activeState == "channel"), ("elvis-mode-library", model.activeState == "library")] ] [
  in
      div [ classList [("elvis", True), ("elvis-mode-channel", True), ("elvis-mode-library", False)] ] [
        div [ class "channels" ] [
          div [ class "mode-wrapper" ] [
            (modeSelectorPanel address model channel)
            , div [ class "zone-view" ] [ Channel.View.root channelAddress model channel ]
            , div [ class "mode-view" ] [
              -- this should be a view dependent on the current view mode (current zone, library, zone chooser)
              -- div [ id "channel" ] (zoneModePanel address model)
            ]
          ]
        ]
      ]


modeSelectorPanel : Signal.Address Action -> Model -> Channel.Model -> Html
modeSelectorPanel address model channel =
  let
      activeState = "channel"
      -- button = case model.activeState of
      button = case activeState of
        "library" ->
          div [ class "block mode-switch", onClick address (SetMode "channel") ] [
            i [ class "fa fa-bullseye" ] []
          ]
        "channel" ->
          div [ class "block mode-switch", onClick address (SetMode "library") ] [
            i [ class "fa fa-music" ] []
          ]
        _ ->
          div [] []
  in
    div [ class "mode-selector" ] [
      div [ class "block-group" ] [
        div [ class "block mode-channel-select", onClick address (ChooseChannel channel) ] [
          i [ class "fa fa-bullseye" ] []
        ]
      , div [ class "block mode-channel" ] [
          -- (Volume.volumeControl channelAddress zone.volume zone.name)
        ]
        , button
      ]
    -- , (zoneSelectorPanel address model)
    ]
