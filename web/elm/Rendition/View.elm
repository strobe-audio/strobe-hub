module Rendition.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Rendition
import Source.View
import Utils.Css


player : Signal.Address () -> Rendition.Model -> Bool -> Html
player playPauseAddress rendition playing =
  let
      source = rendition.source
      coverImage = source.cover_image
      albumMeta = case source.album of
        Nothing ->
          div [] []

        Just album ->
          div [ class "rendition--meta--album" ] [ text (renditionAlbum rendition) ]

      durationMeta = case source.duration_ms of
        Nothing ->
          div [] []

        Just duration ->
           div [ class "rendition--meta--duration" ] [text ("(" ++ (Source.View.duration source) ++ ")")]
  in
    div
      [ id rendition.id, classList [ ( "rendition", True ), ( "rendition__playing", playing ) ]  ]
      [ div
          [ class "rendition--control", onClick playPauseAddress () ]
          [ div
              [ class "rendition--play-pause-btn", style [("backgroundImage", (Utils.Css.url coverImage))] ]
              []
          , div
              [ class "rendition--details" ]
              [ div
                  [ class "rendition--details--top" ]
                  [ div
                    [ classList [ ( "rendition--title", True ), ( "rendition--title__playing", playing ) ] ]
                    [ text (renditionTitle rendition)
                    ]
                  , div [ class "rendition--duration duration" ] [ text (Source.View.timeRemaining rendition.source rendition.playbackPosition) ]
                  ]
              , div
                  [ class "rendition--meta" ]
                  [ div [ class "rendition--meta--artist" ] [ text (renditionPerformer rendition) ]
                  ,  albumMeta
                  ,  durationMeta
                  ]
              , (progress playPauseAddress rendition playing)
              ]
          ]
      ]


cover : Signal.Address () -> Rendition.Model -> Bool -> Html
cover playPauseAddress rendition playing =
  let
      coverImage = rendition.source.cover_image
  in
      div
        [ id rendition.id, class "rendition" ]
        [ div
            [ classList [ ( "rendition--cover", True ), ( "rendition--cover__playing", playing ) ] ]
            [ img [ src coverImage, alt "", onClick playPauseAddress () ] []
            ]
        ]


empty : Html
empty =
  div
    [ class "rendition" ]
    [ div
        [ class "rendition--cover rendition--cover__blank" ]
        []
    ]


progress : Signal.Address () -> Rendition.Model -> Bool -> Html
progress address rendition playing =
  case rendition.source.duration_ms of
    Nothing ->
      div [] []

    Just duration ->
      let
        percent =
          100.0 * (toFloat rendition.playbackPosition) / (toFloat duration)

        progressStyle =
          [ ( "width", (toString percent) ++ "%" ) ]
      in
        div
          [ class "progress" ]
          [ div [ class "progress--complete", style progressStyle ] []
          ]


playlist : Signal.Address Rendition.Action -> Rendition.Model -> Html
playlist address rendition =
  div
    [ key rendition.id
    , class "block playlist--entry"
    , onDoubleClick address Rendition.SkipTo
    ]
    [ div
        [ class "playlist--entry--inner" ]
        [ div
            [ class "playlist--entry--title" ]
            [ strong [] [ text (renditionTitle rendition) ] ]
        , div
            [ class "playlist--entry--album" ]
            [ strong
                []
                [ text (renditionPerformer rendition) ]
            , text ", "
            , text (renditionAlbum rendition)
            ]
        ]
    ]


renditionTitle : Rendition.Model -> String
renditionTitle rendition =
  Maybe.withDefault "Untitled" rendition.source.title


renditionAlbum : Rendition.Model -> String
renditionAlbum rendition =
  Maybe.withDefault "Untitled Album" rendition.source.album


renditionPerformer : Rendition.Model -> String
renditionPerformer rendition =
  Maybe.withDefault "" rendition.source.performer
