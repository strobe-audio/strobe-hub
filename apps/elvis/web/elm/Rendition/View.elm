module Rendition.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed
import Rendition
import Source.View
import Utils.Css
import Progress
import Utils.Touch exposing (onSingleTouch)
import Utils.Css


info : Rendition.Model -> Bool -> Html Rendition.Msg
info rendition playing =
    let
        source =
            rendition.source

        coverImage =
            source.cover_image

        albumMeta =
            case source.album of
                Nothing ->
                    div [] []

                Just album ->
                    div [ class "rendition--meta--detail rendition--meta--album" ] [ text (renditionAlbum rendition) ]

        durationMeta =
            case source.duration_ms of
                Nothing ->
                    div [] []

                Just duration ->
                    div [ class "rendition--meta--detail rendition--meta--duration" ] [ text ("(" ++ (Source.View.duration source) ++ ")") ]
    in
        div [ id rendition.id, classList [ ( "rendition", True ), ( "rendition__playing", playing ) ] ]
            [ div [ class "rendition--control" ]
                [ -- div [ class "rendition--play-pause-btn", style [ ( "backgroundImage", (Utils.Css.url coverImage) ) ] ]
                  --   []
                  div [ class "rendition--details" ]
                    [ div [ class "rendition--details--top" ]
                        [ div [ classList [ ( "rendition--title", True ), ( "rendition--title__playing", playing ) ] ]
                            [ text (renditionTitle rendition)
                            ]
                          -- , div [ class "rendition--duration duration" ] [ text (Source.View.timeRemaining rendition.source rendition.playbackPosition) ]
                        ]
                    , div [ class "rendition--meta" ]
                        [ div [ class "rendition--meta--detail rendition--meta--artist" ] [ text (renditionPerformer rendition) ]
                        , albumMeta
                        , durationMeta
                        ]
                    ]
                ]
            ]


player : Rendition.Model -> Bool -> Html Rendition.Msg
player rendition playing =
    let
        source =
            rendition.source

        coverImage =
            source.cover_image

        albumMeta =
            case source.album of
                Nothing ->
                    div [] []

                Just album ->
                    div [ class "rendition--meta--detail rendition--meta--album" ] [ text (renditionAlbum rendition) ]

        durationMeta =
            case source.duration_ms of
                Nothing ->
                    div [] []

                Just duration ->
                    div [ class "rendition--meta--detail rendition--meta--duration" ] [ text ("(" ++ (Source.View.duration source) ++ ")") ]
    in
        div [ id rendition.id, classList [ ( "rendition", True ), ( "rendition__playing", playing ) ] ]
            [ div [ class "rendition--control", onClick Rendition.PlayPause, onSingleTouch Rendition.PlayPause ]
                [ -- div [ class "rendition--play-pause-btn", style [ ( "backgroundImage", (Utils.Css.url coverImage) ) ] ]
                  --   []
                  div [ class "rendition--details" ]
                    [ div [ class "rendition--details--top" ]
                        [ div [ classList [ ( "rendition--title", True ), ( "rendition--title__playing", playing ) ] ]
                            [ text (renditionTitle rendition)
                            ]
                          -- , div [ class "rendition--duration duration" ] [ text (Source.View.timeRemaining rendition.source rendition.playbackPosition) ]
                        ]
                    , div [ class "rendition--meta" ]
                        [ div [ class "rendition--meta--detail rendition--meta--artist" ] [ text (renditionPerformer rendition) ]
                        , albumMeta
                        , durationMeta
                        ]
                    ]
                , (progress rendition playing)
                ]
            ]


cover : Rendition.Model -> Bool -> Html Rendition.Msg
cover rendition playing =
    let
        coverImage =
            rendition.source.cover_image
    in
        div [ id rendition.id, class "rendition" ]
            [ div [ classList [ ( "rendition--cover", True ), ( "rendition--cover__playing", playing ) ] ]
                [ img
                    [ src coverImage
                    , alt ""
                      -- , onClick Rendition.PlayPause
                      -- , onSingleTouch Rendition.PlayPause
                    ]
                    []
                ]
            ]


empty : Html Rendition.Msg
empty =
    div [ class "rendition" ]
        [ div [ class "rendition--cover rendition--cover__blank" ]
            []
        ]


progress : Rendition.Model -> Bool -> Html Rendition.Msg
progress rendition playing =
    let
        ( percent, color ) =
            case rendition.source.duration_ms of
                Nothing ->
                    ( 100.0
                    , { r = 255, g = 0, b = 0, a = 0.5 }
                    )

                Just duration ->
                    ( 100.0 * (toFloat rendition.playbackPosition) / (toFloat duration)
                    , { r = 255, g = 0, b = 0, a = 1 }
                    )
    in
        div [ classList [ ( "rendition--progress", True ), ( "rendition--progress__playing", playing ) ] ]
            [ Html.map (always Rendition.NoOp) (Progress.circular 50 color playing percent)
            ]


playlist : Rendition.Model -> Html Rendition.Msg
playlist rendition =
    let
        source =
            rendition.source

        coverImage =
            source.cover_image

        mapSwipe a =
            Html.Attributes.map Rendition.Swipe a

        ( swiping, entryStyle ) =
            case rendition.swipe of
                Just swipe ->
                    ( True
                    , [ ( "left", Utils.Css.px -swipe.offset ) ]
                    )

                Nothing ->
                    ( False
                    , []
                    )

        menu =
            if swiping || rendition.menu then
                [ div
                    [ class "playlist--entry--menu__clear"
                    , onClick Rendition.Remove
                    , onSingleTouch Rendition.Remove
                    ]
                    []
                ]
            else
                []
    in
        div
            [ classList
                [ ( "playlist--entry", True )
                , ( "playlist--entry__menu", rendition.menu )
                , ( "playlist--entry__swiping", swiping )
                , ( "playlist--entry__removing", rendition.removeInProgress )
                ]
            , onDoubleClick Rendition.SkipTo
            , mapSwipe (Utils.Touch.touchStart Rendition.NoOp)
            , mapSwipe (Utils.Touch.touchMove Rendition.NoOp)
            , mapSwipe (Utils.Touch.touchEnd Rendition.NoOp)
            ]
            [ div
                [ class "playlist--entry--contents"
                , style entryStyle
                , onClick Rendition.CloseMenu
                ]
                [ div [ class "playlist--entry--image", style [ ( "backgroundImage", "url(" ++ coverImage ++ ")" ) ] ] []
                , div [ class "playlist--entry--inner" ]
                    [ div [ class "playlist--entry--title" ]
                        [ strong [] [ text (renditionTitle rendition) ] ]
                    , div [ class "playlist--entry--album" ]
                        [ strong []
                            [ text (renditionPerformer rendition) ]
                        , text ", "
                        , text (renditionAlbum rendition)
                        ]
                    , div [ class "playlist--entry--duration" ]
                        [ text (Source.View.duration source) ]
                    ]
                , div
                    [ class "playlist--entry--skip"
                    , onClick Rendition.SkipTo
                    , onSingleTouch Rendition.SkipTo
                    ]
                    []
                ]
            , div
                [ class "playlist--entry--menu" ]
                menu
            ]


playlistHead : Rendition.Model -> Html Rendition.Msg
playlistHead rendition =
    let
        source =
            rendition.source

        coverImage =
            source.cover_image

    in
        div
            [ classList
                [ ( "playlist--entry", True )
                , ( "playlist--entry__head", True )
                ]
            ]
            [ div
                [ class "playlist--entry--contents"
                ]
                [ div [ class "playlist--entry--image", style [ ( "backgroundImage", "url(" ++ coverImage ++ ")" ) ] ] []
                , div [ class "playlist--entry--inner" ]
                    [ div [ class "playlist--entry--title" ]
                        [ strong [] [ text (renditionTitle rendition) ] ]
                    , div [ class "playlist--entry--album" ]
                        [ strong []
                            [ text (renditionPerformer rendition) ]
                        , text ", "
                        , text (renditionAlbum rendition)
                        ]
                    , div [ class "playlist--entry--duration" ]
                        [ text (Source.View.duration source) ]
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
