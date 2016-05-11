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
    duration =
      Source.View.durationString (Channel.playlistDuration channel)

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



