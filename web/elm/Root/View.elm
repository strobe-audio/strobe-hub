module Root.View exposing (root)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.App exposing (map)
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
import Msg exposing (Msg)


root : Root.Model -> Html Msg
root model =
  let
    library =
      if Root.State.libraryVisible model then
        map Msg.Library (Library.View.root model.library)
      else
        div [] []

    playlist =
      if Root.State.playlistVisible model then
        map Msg.Channels (Channels.View.playlist model.channels)
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
            {-, on "scroll" (Json.value Msg.Scroll) -}
          ]
          [ map Msg.Channels (Channels.View.channels model.channels model.receivers)
          , div
              [ class "root--active-channel" ]
              [ map Msg.Channels (Channels.View.cover channel)
              -- , Receivers.View.receivers model.receivers channel
              , libraryToggleView model channel
              , library
              , playlist
              ]
          ]


libraryToggleView : Root.Model -> Channel.Model -> Html Msg
libraryToggleView model channel =
  let
    duration =
      Source.View.durationString (Channel.playlistDuration channel)

    playlistButton =
      [ div
          [ classList
              [ ( "root--mode--choice root--mode--playlist", True )
              , ( "root--mode--choice__active", model.listMode == Root.PlaylistMode )
              ]
          , onClick (Msg.SetListMode Root.PlaylistMode)
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
          , onClick (Msg.SetListMode Root.LibraryMode)
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
