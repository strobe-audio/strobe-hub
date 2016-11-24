module Channel.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html
import Debug


--

import Root
import Channel
import Channel.State
import Rendition
import Rendition.View
import Receiver
import Receiver.View


cover : Channel.Model -> Html Channel.Msg
cover channel =
    let
        maybeRendition =
            List.head channel.playlist
    in
        case maybeRendition of
            Nothing ->
                div [ class "channel--rendition" ]
                    [ Html.map (always Channel.NoOp) (Rendition.View.empty)
                    ]

            Just rendition ->
                div [ class "channel--rendition" ]
                    [ Html.map (always Channel.PlayPause) (Rendition.View.cover rendition channel.playing)
                    ]


player : Channel.Model -> Html Channel.Msg
player channel =
    let
        maybeRendition =
            List.head channel.playlist
    in
        case maybeRendition of
            Nothing ->
                div [] [ text "No song..." ]

            Just rendition ->
                div [ class "channel--rendition" ]
                    [ Html.map (always Channel.PlayPause) (Rendition.View.player rendition channel.playing)
                    ]


playlist : Channel.Model -> Html Channel.Msg
playlist channel =
    let
        entry rendition =
            Html.map (Channel.ModifyRendition rendition.id) (Rendition.View.playlist rendition)

        playlist =
            Maybe.withDefault [] (List.tail channel.playlist)

        panel =
            case List.length playlist of
                0 ->
                    div [ class "playlist__empty" ] [ text "Playlist empty" ]

                _ ->
                    div [ class "block-group playlist" ]
                        (List.map entry playlist)

        actionButtons =
            case List.length playlist of
                0 ->
                    []

                _ ->
                    [ div [ class "channel--playlist-actions--space" ] []
                    , div
                        [ class "channel--playlist-actions--clear"
                        , onClick (Channel.ClearPlaylist)
                        ]
                        []
                    ]
    in
        div [ class "channel--playlist" ]
            [ div [ class "channel--playlist-actions" ]
                actionButtons
            , panel
            ]
