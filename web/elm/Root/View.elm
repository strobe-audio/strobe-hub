module Root.View exposing (root)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug
import Root
import Root.State
import Channel
import Channel.View
import Channels.View
import Library.View
import Receivers.View
import Source.View
import Json.Decode as Json
import Msg exposing (Msg)
import Utils.Touch exposing (onUnifiedClick)
import Notification.View
import State


root : Root.Model -> Html Msg
root model =
    case model.connected of
        True ->
            rootWhenConnected model

        False ->
            div
                [ class "root--offline" ]
                [ div [ class "root--offline__message" ] [ text"Offline"]
                ]


rootWhenConnected : Root.Model -> Html Msg
rootWhenConnected model =
    let
        library =
            if Root.State.libraryVisible model then
                Html.map Msg.Library (Library.View.root model.library)
            else
                div [] []

        playlist channel =
            if Root.playlistVisible model then
                Channels.View.playlist channel
            else
                div [] []
    in
        case (Root.State.activeChannel model) of
            Nothing ->
                div [ class "loading" ] [ text "Loading..." ]

            Just channel ->
                div
                    [ classList
                        [ ( "root", True )
                        , ( "root__obscured", (Root.overlayActive model) )
                        ]
                      {- , on "scroll" (Json.value Msg.BrowserScroll) -}
                    ]
                    [ (controlBar model)
                    , (notifications model)
                    , div [ class "root--wrapper" ]
                        [ (Channels.View.channels model)
                        , div
                            [ classList
                                [ ( "root--active-channel", True )
                                , ( "root--active-channel__inactive", model.showChannelSwitcher )
                                ]
                            ]
                            [ (Channels.View.cover channel)
                              -- , Receivers.View.receivers model.receivers channel
                            , libraryToggleView model channel
                            , library
                            , playlist channel
                            ]
                        ]
                    ]



controlBar : Root.Model -> Html Msg
controlBar model =
    case Root.activeChannel model of
        Nothing ->
            div [] []

        Just channel ->
            div [ class "root--bar" ]
                [ (channelSettingsButton model)
                , (currentChannelPlayer channel)
                ]

notifications : Root.Model -> Html Msg
notifications model =
    div
        [ class "root--notifications" ]
        [ (Notification.View.notifications model.animationTime model.notifications)
        ]

channelSettingsButton : Root.Model -> Html Msg
channelSettingsButton model =
    div ([ class "root--channel-select" ] ++ (onUnifiedClick Msg.ToggleChannelSelector))
        [ i [ class "fa fa-bullseye" ] [] ]

currentChannelPlayer : Channel.Model -> Html Msg
currentChannelPlayer channel =
    div
        [ class "root--channel-state" ]
        [ div
            [ class "root--channel-name" ]
            [ div [ class "channel--name" ] [ text channel.name ] ]
        , div
            [ class "root--channel-rendition" ]
            [ Html.map (Msg.Channel channel.id) (Channel.View.player channel) ]
        ]

libraryToggleView : Root.Model -> Channel.Model -> Html Msg
libraryToggleView model channel =
    let
        mapTouch a =
            Html.Attributes.map Msg.SingleTouch a

        duration =
            Source.View.durationString (Channel.playlistDuration channel)

        playlistButton =
            [ div
                [ classList
                    [ ( "root--mode--choice root--mode--playlist", True )
                    , ( "root--mode--choice__active", model.listMode == State.PlaylistMode )
                    ]
                , onClick (Msg.SetListMode State.PlaylistMode)
                , mapTouch (Utils.Touch.touchStart (Msg.SetListMode State.PlaylistMode))
                , mapTouch (Utils.Touch.touchEnd (Msg.SetListMode State.PlaylistMode))
                ]
                -- [ span [ class "root--mode--playlist-label" ] [ text "Playlist" ]
                [ div [ class "root--mode--channel-name" ] [ text "Playlist" ]
                , div [ class "root--mode--channel-duration" ] [ text duration ]
                ]
            ]

        libraryButton =
            [ div
                [ classList
                    [ ( "root--mode--choice root--mode--library", True )
                    , ( "root--mode--choice__active", model.listMode == State.LibraryMode )
                    ]
                , onClick (Msg.SetListMode State.LibraryMode)
                , mapTouch (Utils.Touch.touchStart (Msg.SetListMode State.LibraryMode))
                , mapTouch (Utils.Touch.touchEnd (Msg.SetListMode State.LibraryMode))
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
        div [ class "root--mode" ]
            buttons
