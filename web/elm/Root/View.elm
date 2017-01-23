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
            rootWithActiveChannel model channel


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


notifications : Root.Model -> Html Msg
notifications model =
    div
        [ class "root--notifications" ]
        [ (Notification.View.notifications model.animationTime model.notifications)
        ]


