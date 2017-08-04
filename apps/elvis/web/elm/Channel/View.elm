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
                    [ ( "backgroundImage", renditionCoverImage channel maybeRendition ) ]
                ]
                [ (renditionProgressBar channel maybeRendition)
                , (rewindPlaySkip channel maybeRendition)
                ]
            , (volumeControl model.forcePress channel)
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
    case maybeRendition of
        Nothing ->
            div [] []

        Just rendition ->
            case rendition.source.duration_ms of
                Nothing ->
                    div [] []

                Just duration ->
                    let
                        progress =
                            100.0 * ((toFloat rendition.playbackPosition) / (toFloat duration))

                        progressPercent =
                            (toString progress) ++ "%"
                    in
                        div
                            [ classList
                                [ ( "channel--rendition-progress", True ) ]
                            ]
                            [ div
                                [ class "channel--rendition-progress--time channel--rendition-progress--played-time" ]
                                [ text (Source.View.durationString (Just rendition.playbackPosition)) ]
                            , div
                                [ class "channel--rendition-progress--bar-outer" ]
                                [ div
                                    [ class "channel--rendition-progress--bar-inner", style [ ( "width", progressPercent ) ] ]
                                    []
                                ]
                            , div
                                [ class "channel--rendition-progress--time channel--rendition-progress--remaining-time" ]
                                [ text (Source.View.timeRemaining rendition.source rendition.playbackPosition) ]
                            ]


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
                    [ ( "channel--play-control-btn", True )
                    , ( "channel--play-control-btn__enabled", active )
                    , ( "channel--rewind", True )
                    ]
                ]
                []
            , div
                [ classList
                    [ ( "channel--play-control-btn", True )
                    , ( "channel--play-control-btn__enabled", active )
                    , ( "channel--pause", channel.playing )
                    , ( "channel--play", not channel.playing )
                    ]
                , onClick Channel.PlayPause
                , mapTap (Utils.Touch.touchStart Channel.PlayPause)
                , mapTap (Utils.Touch.touchEnd Channel.PlayPause)
                ]
                []
            , div
                [ classList
                    [ ( "channel--play-control-btn", True )
                    , ( "channel--play-control-btn__enabled", active )
                    , ( "channel--skip", True )
                    ]
                , onClick Channel.SkipNext
                , mapTap (Utils.Touch.touchStart Channel.SkipNext)
                , mapTap (Utils.Touch.touchEnd Channel.SkipNext)
                ]
                []
            ]


volumeControl : Bool -> Channel.Model -> Html Channel.Msg
volumeControl forcePress channel =
    let
        volumeCtrl =
            (Volume.View.control forcePress
                channel.volume
                False
                (div [ class "channel--volume-label" ] [ text "Master volume" ])
            )
    in
        div
            [ class "channel--volume-control" ]
            [ Html.map (\m -> (Channel.Volume m)) volumeCtrl
            ]


playlist : Channel.Model -> Html Channel.Msg
playlist channel =
    let
        entry rendition =
            Html.map (Channel.ModifyRendition rendition.id) (Rendition.View.playlist rendition)

        ( active, pending ) =
            List.partition (\r -> r.active) channel.playlist

        actionButtons =
            case List.length pending of
                0 ->
                    div []
                        [ playlistDivision ""
                        , div [ class "playlist__empty" ] [ text "Playlist empty" ]
                        ]

                _ ->
                    div [ class "channel--playlist-actions" ]
                        [ div [ class "channel--playlist-actions--label" ] [ text "Queued" ]
                        , div [ class "channel--playlist-actions--space" ] []
                        , div
                            [ class "channel--playlist-actions--clear"
                            , onClick (Channel.ClearPlaylist)
                            , onSingleTouch (Channel.ClearPlaylist)
                            ]
                            []
                        ]

        playlist =
            case List.length channel.playlist of
                0 ->
                    div [ class "playlist__empty" ] [ text "Playlist empty" ]

                _ ->
                    div
                        [ class "channel--playlist--entries" ]
                        [ div [ class "channel--playlist--head" ] [ (playlistHead channel active) ]
                        , actionButtons
                        , div [ class "channel--playlist--tail" ] (List.map entry pending)
                        ]
    in
        div [ id "__scrolling__", class "channel--playlist" ] [ playlist ]


playlistHead : Channel.Model -> List Rendition.Model -> Html Channel.Msg
playlistHead channel active =
    case active of
        [] ->
            div [] []

        rendition :: rest ->
            div
                []
                [ playlistDivision "Currently playing"
                , Html.map (Channel.ModifyRendition rendition.id) (Rendition.View.playlistHead rendition)
                ]


playPauseButton : Channel.Model -> Html Channel.Msg
playPauseButton channel =
    div
        [ classList
            [ ( "channel--play-pause-btn", True )
            , ( "channel--play-pause-btn__play", channel.playing )
            , ( "channel--play-pause-btn__pause", not channel.playing )
            ]
        , onClick Channel.PlayPause
        , mapTap (Utils.Touch.touchStart Channel.PlayPause)
        , mapTap (Utils.Touch.touchEnd Channel.PlayPause)
        ]
        []


playlistDivision : String -> Html Channel.Msg
playlistDivision title =
    div [ class "channel--playlist-division" ] [ text title ]


mapTap : Attribute (Utils.Touch.E Channel.Msg) -> Attribute Channel.Msg
mapTap a =
    Html.Attributes.map Channel.Tap a
