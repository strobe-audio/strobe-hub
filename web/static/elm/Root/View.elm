module Root.View (root) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug
import Root
import Root.State
import Channel
import Channels
import Channel.View
import Channels.View
import Library.View
import Receivers.View
import Source.View
import Json.Decode as Json
import Player.View


root : Signal.Address Root.Action -> Root.Model -> Html
root address model =
  let
    channelsAddress =
      Signal.forwardTo address Root.Channels

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

    overlayActive = Channels.overlayActive model.channels

  in
    case (Root.State.activeChannel model) of
      Nothing ->
        div [ class "loading" ] [ text "Loading..." ]

      Just channel ->
        div
          [ classList
            [ ("root", True)
            , ("root__obscured", overlayActive)
            ]
            {-, on "scroll" Json.value (Signal.message address << Root.Scroll) -}
          ]
          [ Channels.View.channels channelsAddress model.channels receiversAddress model.receivers
          , Channels.View.player channelsAddress channel
          -- , Receivers.View.receivers receiversAddress model.receivers channel
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
          [ div [ class "root--mode--channel-name" ] [ text channel.name ]
          , div [ class "root--mode--channel-duration" ] [ text duration ]
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
