module View (root) where


import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug

import Root
import State
import Channel
import Channel.View
import Volume.View

root : Signal.Address Root.Action -> Root.Model -> Html
root address model =
  let
      activeChannel = (State.activeChannel model)
  in
    case activeChannel of
      Nothing ->
        div [] [ text "NO ACTIVE CHANNEL" ]
      Just channel ->
        activeChannelView address model channel

activeChannelView : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
activeChannelView address model channel =
  let
      channelAddress = Signal.forwardTo address (Root.ModifyChannel channel.id)
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


modeSelectorPanel : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
modeSelectorPanel address model channel =
  let
      activeState = "channel"
      channelAddress = Signal.forwardTo address (Root.ModifyChannel channel.id)
      volumeAddress = Signal.forwardTo channelAddress Channel.Volume
      -- button = case model.activeState of
      button = case activeState of
        "library" ->
          div [ class "block mode-switch", onClick address (Root.SetMode "channel") ] [
            i [ class "fa fa-bullseye" ] []
          ]
        "channel" ->
          div [ class "block mode-switch", onClick address (Root.SetMode "library") ] [
            i [ class "fa fa-music" ] []
          ]
        _ ->
          div [] []
  in
    div [ class "mode-selector" ]
      [ div [ class "block-group" ]
        [ div
          [ class "block mode-channel-select", onClick address (Root.ToggleChannelSelector) ]
          [ i [ class "fa fa-bullseye" ] [] ]
        , div [ class "block mode-channel" ]
          [ (Volume.View.control volumeAddress channel.volume channel.name) ]
        , button
        ]
      , (channelSelectorPanel address model channel)
      ]


channelSelectorPanel : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
channelSelectorPanel address model activeChannel =
  let
      channelChoice channel =
        div [ class "channel-selector--channel", onClick address (Root.ChooseChannel channel) ]
          [ text channel.name ]
      unselectedChannels = List.filter (\channel -> channel.id /= activeChannel.id) model.channels
  in
    case model.showChannelSwitcher of
      False ->
        div [] []
      True ->
        div [ class "channel-selector" ]
          ( List.map channelChoice  unselectedChannels)


