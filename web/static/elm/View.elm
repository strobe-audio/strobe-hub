module View (root) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug
import Json.Decode as Json
import Root
import State
import Channel
import Channel.View
import Volume.View
import Library.View
import Input
import Input.View


root : Signal.Address Root.Action -> Root.Model -> Html
root address model =
  let
    activeChannel =
      (State.activeChannel model)
  in
    case activeChannel of
      Nothing ->
        div [] [ text "NO ACTIVE CHANNEL" ]

      Just channel ->
        activeChannelView address model channel


activeChannelView : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
activeChannelView address model channel =
  let
    context =
      { receiverAddress = (\receiver -> (Signal.forwardTo address (Root.ModifyReceiver receiver.id)))
      , channelAddress = (Signal.forwardTo address (Root.ModifyChannel channel.id))
      , attached = (State.attachedReceivers model channel)
      , detached = (State.detachedReceivers model channel)
      }

    channelAddress =
      Signal.forwardTo address (Root.ModifyChannel channel.id)

    libraryView =
      Library.View.root (Signal.forwardTo address Root.Library) model.library

    libraryVisible =
      State.libraryVisible model

    playlistVisible =
      State.playlistVisible model

    library =
      case libraryVisible of
        True ->
          libraryView

        False ->
          div [] []
  in
    div
      -- TODO: could simplify this
      [ class "elvis" ]
      [ div
          [ class "channels" ]
          [ div
              [ class "mode-wrapper" ]
              [ (modeSelectorPanel address model channel)
              , div [ class "channel-view" ] [ Channel.View.root context channel playlistVisible ]
              ]
          ]
      , div [ id "library" ] [ library ]
      ]


modeSelectorPanel : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
modeSelectorPanel address model channel =
  let
    channelAddress =
      Signal.forwardTo address (Root.ModifyChannel channel.id)

    volumeAddress =
      Signal.forwardTo channelAddress Channel.Volume

    -- button = case model.activeState of
    button =
      case model.listMode of
        Root.LibraryMode ->
          div
            [ class "mode-switch", onClick address (Root.SetListMode Root.PlaylistMode) ]
            [ i [ class "fa fa-bullseye" ] []
            ]

        Root.PlaylistMode ->
          div
            [ class "mode-switch", onClick address (Root.SetListMode Root.LibraryMode) ]
            [ i [ class "fa fa-music" ] []
            ]
  in
    div
      [ class "mode-selector" ]
      [ div
          [ class "mode-current-channel" ]
          [ div
              [ class "mode-channel-select", onClick address (Root.ToggleChannelSelector) ]
              [ i [ class "fa fa-bullseye" ] [] ]
          , div
              [ class "mode-channel" ]
              [ (Volume.View.control volumeAddress channel.volume channel.name) ]
          , button
          ]
      , (channelSelectorPanel address model channel)
      ]


channelSelectorPanel : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
channelSelectorPanel address model activeChannel =
  let
    channelChoice channel =
      div
        [ class "channel-selector--channel", onClick address (Root.ChooseChannel channel) ]
        [ text channel.name ]

    unselectedChannels =
      List.filter (\channel -> channel.id /= activeChannel.id) model.channels
  in
    case model.showChannelSwitcher of
      False ->
        div [] []

      True ->
        div
          [ class "channel-selector" ]
          [ div
              [ class "channel-selector--select" ]
              (List.map channelChoice unselectedChannels)
          , addChannelPanel address model
          ]


addChannelPanel : Signal.Address Root.Action -> Root.Model -> Html
addChannelPanel address model =
  let
      context =
        { address = Signal.forwardTo address Root.NewChannelInput
        , cancelAddress = Signal.forwardTo address (always Root.ToggleAddChannel)
        , submitAddress = Signal.forwardTo address Root.AddChannel }
  in
    case model.showAddChannel of
      False ->
        div
          [ class "channel-selector--add", onClick address (Root.ToggleAddChannel) ]
          [ text "Add new channel..." ]

      True ->
        Input.View.inputSubmitCancel context model.newChannelInput
