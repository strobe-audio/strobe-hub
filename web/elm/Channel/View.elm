module Channel.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug
import Root
import Channel
import Channel.State
import Rendition
import Rendition.View
import Receiver
import Receiver.View


cover : Signal.Address Channel.Action -> Channel.Model -> Html
cover address channel =
  let
    maybeRendition =
      List.head channel.playlist

    playPauseAddress =
      Signal.forwardTo address (always Channel.PlayPause)
  in
    case maybeRendition of
      Nothing ->
        div
          [ class "channel--rendition" ]
          [ (Rendition.View.empty)
          ]

      Just rendition ->
        div
          [ class "channel--rendition" ]
          [ (Rendition.View.cover playPauseAddress rendition channel.playing)
          ]


player : Signal.Address Channel.Action -> Channel.Model -> Html
player address channel =
  let
    maybeRendition =
      List.head channel.playlist

    playPauseAddress =
      Signal.forwardTo address (always Channel.PlayPause)

  in
    case maybeRendition of
      Nothing ->
        div [] [ text "No song..." ]

      Just rendition ->
        div
          [ class "channel--rendition" ]
          [ (Rendition.View.player playPauseAddress rendition channel.playing)
          ]


playlist : Signal.Address Channel.Action -> Channel.Model -> Html
playlist address channel =
  let
    entry rendition =
      let
        renditionAddress =
          Signal.forwardTo address (Channel.ModifyRendition rendition.id)
      in
        Rendition.View.playlist renditionAddress rendition

    playlist =
      Maybe.withDefault [] (List.tail channel.playlist)

    panel =
      case List.length playlist of
        0 ->
          div [ class "playlist__empty" ] [ text "Playlist empty" ]

        _ ->
          div
            [ class "block-group playlist" ]
            (List.map entry playlist)
    actionButtons = case  List.length playlist of
        0 ->
          [ ]

        _ ->
          [ div [ class "channel--playlist-actions--space" ] []
          , div
            [ class "channel--playlist-actions--clear"
            , onClick address (Channel.ClearPlaylist)
            ]
            []
          ]
  in
    div
      [ class "channel--playlist" ]
      [ div
          [ class "channel--playlist-actions" ]
          actionButtons
      , panel
      ]
