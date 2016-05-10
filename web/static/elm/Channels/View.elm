module Channels.View (channels, player) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug
import Json.Decode as Json
import Root
import State
import Channels
import Channel
import Channel.View
import Volume.View
import Library.View
import Input
import Input.View


orderedChannels : List Channel.Model -> List Channel.Model
orderedChannels channels =
  List.sortBy (\c -> c.name) channels


channels : Signal.Address Channels.Action -> Channels.Model -> Channel.Model -> Html
channels address model activeChannel =
  let
    channelAddress =
      Signal.forwardTo address (Channels.Modify activeChannel.id)

    volumeAddress =
      Signal.forwardTo channelAddress Channel.Volume
  in
    div
      [ classList [ ( "channels", True ), ( "channels__select-channel", model.showChannelSwitcher ) ] ]
      [ div
          [ class "channels--bar" ]
          [ div
              [ class "channels--channel-select", onClick address (Channels.ToggleSelector) ]
              [ i [ class "fa fa-bullseye" ] [] ]
          , div
              [ class "channels--channel-volume" ]
              [ (Volume.View.control volumeAddress activeChannel.volume activeChannel.name) ]
          ]
      , (channelSelectorPanel address model activeChannel)
      ]


channelSelectorPanel : Signal.Address Channels.Action -> Channels.Model -> Channel.Model -> Html
channelSelectorPanel address model activeChannel =
  let
    channelChoice channel =
      case channel.id == activeChannel.id of
        False ->
          div
            [ class "channels-selector--channel", onClick address (Channels.Choose channel) ]
            [ text channel.name ]
        True ->
          div
            [ class "channels-selector--channel channels-selector--channel__active"  ]
            [ text channel.name ]

    -- unselectedChannels =
    --   List.filter (\channel -> channel.id /= activeChannel.id) model.channels

    channels = orderedChannels model.channels

  in
    case model.showChannelSwitcher of
      False ->
        div [] []

      True ->
        div
          [ class "channels-selector" ]
          [ div
              [ class "channels-selector--list" ]
              (List.map channelChoice channels)
          , addChannelPanel address model
          ]


addChannelPanel : Signal.Address Channels.Action -> Channels.Model -> Html
addChannelPanel address model =
  let
      context =
        { address = Signal.forwardTo address Channels.NewInput
        , cancelAddress = Signal.forwardTo address (always Channels.ToggleAdd)
        , submitAddress = Signal.forwardTo address Channels.Add }
  in
    case model.showAddChannel of
      False ->
        div
          [ class "channel-selector--add", onClick address (Channels.ToggleAdd) ]
          [ text "Add new channel..." ]

      True ->
        Input.View.inputSubmitCancel context model.newChannelInput


player : Signal.Address Channels.Action -> Channel.Model -> Html
player address channel =
  let
      playerAddress = Signal.forwardTo address (Channels.Modify channel.id)
  in
    Channel.View.root playerAddress channel



-- root : Channels.Context -> Root.Model -> Channel.Model -> Html
-- root context model activeChannel =
--   activeChannelView context model channel
--
--
-- activeChannelView : Channels.Context -> Root.Model -> Channel.Model -> Html
-- activeChannelView context model channel =
--   let
--     address = context.address
--     modeAddress = context.modeAddress
--     context =
--       { receiverAddress = (\receiver -> (Signal.forwardTo address (Root.ModifyReceiver receiver.id)))
--       , channelAddress = (Signal.forwardTo address (Channels.Modify channel.id))
--       , attached = (State.attachedReceivers model channel)
--       , detached = (State.detachedReceivers model channel)
--       }
--
--     channelAddress =
--       Signal.forwardTo address (Channels.Modify channel.id)
--
--     libraryView =
--       Library.View.root (Signal.forwardTo address Root.Library) model.library
--
--     libraryVisible =
--       State.libraryVisible model
--
--     playlistVisible =
--       State.playlistVisible model
--
--     library =
--       case libraryVisible of
--         True ->
--           libraryView
--
--         False ->
--           div [] []
--   in
--     div
--       -- TODO: could simplify this
--       [ class "elvis" ]
--       [ div
--           [ class "channels" ]
--           [ div
--               [ class "mode-wrapper" ]
--               [ (modeSelectorPanel address model channel)
--               , div [ class "channel-view" ] [ Channel.View.root context channel playlistVisible ]
--               ]
--           ]
--       , div [ id "library" ] [ library ]
--       ]
--
--
-- modeSelectorPanel : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
-- modeSelectorPanel address model channel =
--   let
--     channelAddress =
--       Signal.forwardTo address (Root.ModifyChannel channel.id)
--
--     volumeAddress =
--       Signal.forwardTo channelAddress Channel.Volume
--
--     -- button = case model.activeState of
--     button =
--       case model.listMode of
--         Root.LibraryMode ->
--           div
--             [ class "mode-switch", onClick address (Root.SetListMode Root.PlaylistMode) ]
--             [ i [ class "fa fa-bullseye" ] []
--             ]
--
--         Root.PlaylistMode ->
--           div
--             [ class "mode-switch", onClick address (Root.SetListMode Root.LibraryMode) ]
--             [ i [ class "fa fa-music" ] []
--             ]
--   in
--     div
--       [ classList [("mode-selector", True), ("mode-selector__select-channel", model.showChannelSwitcher)] ]
--       [ div
--           [ class "mode-current-channel" ]
--           [ div
--               [ class "mode-channel-select", onClick address (Root.ToggleChannelSelector) ]
--               [ i [ class "fa fa-bullseye" ] [] ]
--           , div
--               [ class "mode-channel" ]
--               [ (Volume.View.control volumeAddress channel.volume channel.name) ]
--           , button
--           ]
--       , (channelSelectorPanel address model channel)
--       ]
--
--
-- channelSelectorPanel : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
-- channelSelectorPanel address model activeChannel =
--   let
--     channelChoice channel =
--       div
--         [ class "channel-selector--channel", onClick address (Root.ChooseChannel channel) ]
--         [ text channel.name ]
--
--     unselectedChannels =
--       List.filter (\channel -> channel.id /= activeChannel.id) model.channels
--   in
--     case model.showChannelSwitcher of
--       False ->
--         div [] []
--
--       True ->
--         div
--           [ class "channel-selector" ]
--           [ div
--               [ class "channel-selector--select" ]
--               (List.map channelChoice unselectedChannels)
--           , addChannelPanel address model
--           ]
--
--
-- addChannelPanel : Signal.Address Root.Action -> Root.Model -> Html
-- addChannelPanel address model =
--   let
--       context =
--         { address = Signal.forwardTo address Root.NewChannelInput
--         , cancelAddress = Signal.forwardTo address (always Root.ToggleAddChannel)
--         , submitAddress = Signal.forwardTo address Root.AddChannel }
--   in
--     case model.showAddChannel of
--       False ->
--         div
--           [ class "channel-selector--add", onClick address (Root.ToggleAddChannel) ]
--           [ text "Add new channel..." ]
--
--       True ->
--         Input.View.inputSubmitCancel context model.newChannelInput
--
