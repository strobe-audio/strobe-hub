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


root : Signal.Address Channel.Action -> Channel.Model -> Html
root address channel =
  let
    rendition =
      List.head channel.playlist

    playPauseAddress =
      Signal.forwardTo address (always Channel.PlayPause)
  in
    playingSong playPauseAddress channel rendition


playingSong : Signal.Address () -> Channel.Model -> Maybe Rendition.Model -> Html
playingSong address channel maybeRendition =
  case maybeRendition of
    Nothing ->
      div [] [ text "No song..." ]

    Just rendition ->
      div
        [ class "channel--rendition" ]
        [ (Rendition.View.playing address rendition channel.playing)
        , (Rendition.View.progress address rendition channel.playing)
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
  in
    div
      [ class "channel-playlist" ]
      [ div [ class "divider" ] [ text "Playlist" ]
      , div
          [ class "block-group channel-playlist" ]
          (List.map entry playlist)
      ]
