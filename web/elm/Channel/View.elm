module Channel.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html
import Debug


--

import Msg exposing (Msg)
import Root
import Channel
import Channel.State
import Rendition
import Rendition.View
import Receiver
import Receiver.View
import Utils.Touch exposing (onSingleTouch)
import Source.View
import Volume.View


control : Root.Model -> Channel.Model -> Html Channel.Msg
control model channel =
    let
        maybeRendition =
            List.head channel.playlist
    in
        div
            [ class "channel--control" ]
            [ div
                [ class "channel--rendition-cover"
                , style
                    [ ("backgroundImage", renditionCoverImage channel maybeRendition) ]
                ]
                [ (renditionProgressBar channel maybeRendition)
                , (rewindPlaySkip channel maybeRendition)
                ]
            , (volumeControl channel)
            -- , (receiverControl model channel)
            ]


renditionCoverImage : Channel.Model -> Maybe Rendition.Model -> String
renditionCoverImage channel maybeRendition =
    case maybeRendition of
        Nothing ->
            ""

        Just rendition ->
            "url(" ++ rendition.source.cover_image ++ ")"



renditionProgressBar : Channel.Model -> Maybe Rendition.Model -> Html Channel.Msg
renditionProgressBar channel maybeRendition =
    let
        progress =
            case maybeRendition of
                Nothing ->
                    []

                Just rendition ->
                    let
                        progress =
                            case rendition.source.duration_ms of
                                Nothing ->
                                    0.0

                                Just duration ->
                                    100.0 * ((toFloat rendition.playbackPosition) / (toFloat duration))

                        progressPercent =
                            (toString progress) ++ "%"

                    in
                        [ div
                            [ class "channel--rendition-progress--time channel--rendition-progress--played-time" ]
                            [ text (Source.View.durationString (Just rendition.playbackPosition)) ]
                        , div
                            [ class "channel--rendition-progress--bar-outer" ]
                            [ div
                                [ class "channel--rendition-progress--bar-inner", style [("width", progressPercent)] ]
                                []
                            ]
                        , div
                            [ class "channel--rendition-progress--time channel--rendition-progress--remaining-time" ]
                            [ text (Source.View.timeRemaining rendition.source rendition.playbackPosition) ]
                        ]

    in
        div
            [ classList
                [ ("channel--rendition-progress", True) ]
            ]
            progress


rewindPlaySkip : Channel.Model -> Maybe Rendition.Model -> Html Channel.Msg
rewindPlaySkip channel maybeRendition =
    let
        active =
            Maybe.map (\r -> True) maybeRendition
                |> Maybe.withDefault False

    in
        div
            [ class "channel--rewind-play-skip" ]
            [ div
                [ classList
                    [ ("channel--play-control-btn", True)
                    , ("channel--play-control-btn__enabled", active)
                    , ("channel--rewind", True)
                    ]
                ]
                []
            , div
                [ classList
                    [ ("channel--play-control-btn", True)
                    , ("channel--play-control-btn__enabled", active)
                    , ("channel--pause", channel.playing)
                    , ("channel--play", not channel.playing)
                    ]
                , onClick Channel.PlayPause
                , mapTap (Utils.Touch.touchStart Channel.PlayPause)
                , mapTap (Utils.Touch.touchEnd Channel.PlayPause)
                ]
                []
            , div
                [ classList
                    [ ("channel--play-control-btn", True)
                    , ("channel--play-control-btn__enabled", active)
                    , ("channel--skip", True)
                    ]
                ]
                []
            ]


volumeControl : Channel.Model -> Html Channel.Msg
volumeControl channel =
    let
        volumeCtrl =
            (Volume.View.control channel.volume
                (text "Master volume")
            )
    in
        div
            [ class "channel--volume-control" ]
            [ Html.map (\m -> (Channel.Volume m)) volumeCtrl
            ]





-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

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
                div
                    [ class "channel--rendition"
                    , mapTap (Utils.Touch.touchStart Channel.PlayPause)
                    , mapTap (Utils.Touch.touchEnd Channel.PlayPause)
                    ]
                    [ Html.map (always Channel.PlayPause) (Rendition.View.cover rendition channel.playing)
                    ]


player : Channel.Model -> Html Channel.Msg
player channel =
    let
        maybeRendition =
            List.head channel.playlist

        rendition =
            case maybeRendition of
                Nothing ->
                    div [] [ text "No song..." ]

                Just rendition ->
                    div [ class "channel--rendition" ]
                        [ Html.map (always Channel.NoOp) (Rendition.View.info rendition channel.playing)
                        ]

        progress =
            case maybeRendition of
                Nothing ->
                    div [] []

                Just rendition ->
                    div
                        [ onClick Channel.PlayPause
                        -- , mapTap (Utils.Touch.touchStart Channel.PlayPause)
                        -- , mapTap (Utils.Touch.touchEnd Channel.PlayPause)
                        ]
                        [ Html.map
                            (always Channel.PlayPause)
                            (Rendition.View.progress rendition channel.playing)
                        ]
    in
        div
            [ class "channel--playback"
            -- , onClick Channel.PlayPause
            -- , mapTap (Utils.Touch.touchStart Channel.PlayPause)
            -- , mapTap (Utils.Touch.touchEnd Channel.PlayPause)
            ]
            [ div
                [ class "channel--info" ]
                [ div
                    [ class "channel--info--name" ]
                    [ div
                        [ class "channel--name" ]
                        [ text channel.name ]
                    ]
                , rendition
                ]
            -- , progress
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
                        , onSingleTouch (Channel.ClearPlaylist)
                        ]
                        []
                    ]
    in
        div [ id "__scrolling__", class "channel--playlist" ]
            [ div [ class "channel--playlist-actions" ]
                actionButtons
            , panel
            ]


mapTap : Attribute (Utils.Touch.E Channel.Msg) -> Attribute Channel.Msg
mapTap a =
    Html.Attributes.map Channel.Tap a
