module Root.View (root) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug
import Json.Decode as Json
import Root
import Root.State
import Channel
import Channel.View
import Channels
import Channels.View
import Volume.View
import Library.View
import Input
import Input.View
import Receivers.View
import Source.View


root : Signal.Address Root.Action -> Root.Model -> Html
root address model =
  let
    channels =
      model.channels

    activeChannel =
      (Root.State.activeChannel model)

    context =
      { address = Signal.forwardTo address Root.Channels
      , modeAddress = Signal.forwardTo address Root.SetListMode
      }

    receiversAddress =
      Signal.forwardTo address Root.Receivers

    library =
      if Root.State.libraryVisible model then
        Library.View.root (Signal.forwardTo address Root.Library) model.library
      else
        div [] []

    playlist =
      if Root.State.playlistVisible model then
        Channels.View.playlist (Signal.forwardTo address Root.Channels) model.channels
      else
        div [] []


  in
    case activeChannel of
      Nothing ->
        div [ class "loading" ] [ text "Loading..." ]

      Just channel ->
        div
          [ class "root" ]
          [ Channels.View.channels context.address channels channel
          , Channels.View.player context.address channel
          , Receivers.View.receivers receiversAddress model.receivers channel
          , libraryToggleView address model channel
          , library
          , playlist
          ]


libraryToggleView : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
libraryToggleView address model channel =
  let
    duration = Source.View.durationString (Channel.playlistDuration channel)
    playlistButton =
      [ div
          [ classList
              [ ( "root--mode--choice root--mode--playlist", True )
              , ( "root--mode--choice__active", model.listMode == Root.PlaylistMode )
              ]
          , onClick address (Root.SetListMode Root.PlaylistMode)
          ]
          -- [ span [ class "root--mode--playlist-label" ] [ text "Playlist" ]
          [ span [ class "root--mode--channel-name" ] [ text channel.name ]
          , span [ class "root--mode--channel-duration" ] [ text duration ]
          ]
      ]

    libraryButton =
      [ div
          [ classList
              [ ( "root--mode--choice root--mode--library", True )
              , ( "root--mode--choice__active", model.listMode == Root.LibraryMode )
              ]
          , onClick address (Root.SetListMode Root.LibraryMode)
          ]
          [ text "Library" ]
      ]

    buttons =
      case model.showPlaylistAndLibrary of
        True ->
          playlistButton

        False ->
          List.append playlistButton libraryButton
  in
    div
      [ class "root--mode" ]
      buttons



-- activeChannelView : Signal.Address Root.Action -> Root.Model -> Channel.Model -> Html
-- activeChannelView address model channel =
--   let
--     context =
--       { receiverAddress = (\receiver -> (Signal.forwardTo address (Root.ModifyReceiver receiver.id)))
--       , channelAddress = (Signal.forwardTo address (Root.ModifyChannel channel.id))
--       , attached = (State.attachedReceivers model channel)
--       , detached = (State.detachedReceivers model channel)
--       }
--
--     channelAddress =
--       Signal.forwardTo address (Root.ModifyChannel channel.id)
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
