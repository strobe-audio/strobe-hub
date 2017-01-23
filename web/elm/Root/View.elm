module Root.View exposing (root)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy exposing (lazy, lazy2)
import Debug
import Root
import Root.State
import Channel
import Channel.View
import Channels.View
import Library.View
import Receivers.View
import Rendition.View
import Source.View
import Json.Decode as Json
import Msg exposing (Msg)
import Utils.Touch exposing (onUnifiedClick)
import Notification.View
import State
import Spinner


root : Root.Model -> Html Msg
root model =
    case model.connected of
        True ->
            rootWhenConnected model

        False ->
            div
                [ class "root--offline" ]
                [ div
                    [ class "root--offline__message" ]
                    [ Spinner.ripple
                    , text "Connecting"
                    ]
                ]


rootWhenConnected : Root.Model -> Html Msg
rootWhenConnected model =
    case (Root.State.activeChannel model) of
        Nothing ->
            div [ class "loading" ] [ text "Loading..." ]

        Just channel ->
            lazy2 rootWithActiveChannel model channel


rootWithActiveChannel : Root.Model -> Channel.Model -> Html Msg
rootWithActiveChannel model channel =
    let
        contents =
            div [] [ text "contents..." ]
    in
        div
            [ id "root" ]
            [ (activeRendition model channel)
            , (notifications model)
            , (activeView model channel)
            , (switchView model channel)
            ]

activeRendition : Root.Model -> Channel.Model -> Html Msg
activeRendition model channel =
    let
        maybeRendition =
            List.head channel.playlist

        mapTouch a =
            Html.Attributes.map Channel.Tap a

        progress =
            case maybeRendition of
                Nothing ->
                    div [] []

                Just rendition ->
                    div
                        [ onClick Channel.PlayPause
                        , mapTouch (Utils.Touch.touchStart Channel.PlayPause)
                        , mapTouch (Utils.Touch.touchEnd Channel.PlayPause)
                        ]
                        [ Html.map
                            (always Channel.PlayPause)
                            (Rendition.View.progress rendition channel.playing)
                        ]

    in
        div [ class "root--active-rendition" ]
            [ Html.map (Msg.Channel channel.id) (Channel.View.player channel)
            , Html.map (Msg.Channel channel.id) progress
            ]



activeView : Root.Model -> Channel.Model -> Html Msg
activeView model channel =
    let
        view =
            case model.viewMode of
                State.ViewCurrentChannel ->
                    Html.map (Msg.Channel channel.id) (lazy Channel.View.playlist channel)

                State.ViewChannelSwitch ->
                    Channels.View.channel model channel

                State.ViewLibrary ->
                    Html.map Msg.Library (Library.View.root model.library)

                State.ViewSettings ->
                    text "View Settings"
    in
        div
            [ class "root--active-view" ]
            [ view ]


switchView : Root.Model -> Channel.Model -> Html Msg
switchView model channel =
    div
        [ class "root--switch-view" ]
        (List.map (switchViewButton model) State.viewModes)


switchViewButton : Root.Model -> State.ViewMode -> Html Msg
switchViewButton model mode =
    div
        [ classList
            [ ( "root--switch-view--btn", True )
            , ( "root--switch-view--btn__active", model.viewMode == mode )
            , ( "root--switch-view--btn__"++ (toString mode), True )
            ]
        , onClick (Msg.ActivateView mode)
        , mapTouch (Utils.Touch.touchStart (Msg.ActivateView mode))
        , mapTouch (Utils.Touch.touchEnd (Msg.ActivateView mode))
        ]
        [ text (State.viewLabel mode) ]


mapTouch : Attribute (Utils.Touch.E Msg) -> Attribute Msg
mapTouch a =
    Html.Attributes.map Msg.SingleTouch a


-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

old_rootWhenConnected : Root.Model -> Html Msg
old_rootWhenConnected model =
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
            [ class "root--channel-rendition" ]
            [ Html.map (Msg.Channel channel.id) (Channel.View.player channel)
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
