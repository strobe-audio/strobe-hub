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
import Receiver
import Receivers.View
import Rendition.View
import Source.View
import Json.Decode as Json
import Msg exposing (Msg)
import Utils.Touch exposing (onUnifiedClick)
import Notification.View
import State
import Spinner
import Settings.View


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
    div
        [ id "root"
        , classList
            [ ("root--channel-select__active", model.showSelectChannel)
            , ("root--channel-select__inactive", not model.showSelectChannel)
            , ("root--channel-control__active", model.showChannelControl)
            , ("root--channel-control__inactive", not model.showChannelControl)
            ]
        ]
        [ (selectChannel model channel)
        , (channelView model channel)
        ]


selectChannel : Root.Model -> Channel.Model -> Html Msg
selectChannel model channel =
    case model.showSelectChannel of
        True ->
            div [ class "root--channel-list" ]
                [ div
                    []
                    [ Channels.View.channelSelector model channel ]
                , div
                    [ class "root--channel-list-toggle"
                    , onClick (Msg.ToggleShowChannelSelector)
                    , mapTouch (Utils.Touch.touchStart (Msg.ToggleShowChannelSelector))
                    , mapTouch (Utils.Touch.touchEnd (Msg.ToggleShowChannelSelector))
                    ]
                    []
                ]

        False ->
            div [ class "root--channel-list" ] []


channelView : Root.Model -> Channel.Model -> Html Msg
channelView model channel =
    div
        [ class "root--channel" ]
        [ (switchView model channel)
        , (notifications model)
        -- , (channelControl model channel)
        , (activeView model channel)
        , (activeRendition model channel)
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
                    lazy2
                        (\r p ->
                            div
                                [ onClick Channel.PlayPause
                                , mapTouch (Utils.Touch.touchStart Channel.PlayPause)
                                , mapTouch (Utils.Touch.touchEnd Channel.PlayPause)
                                ]
                                [ Html.map
                                    (always Channel.NoOp)
                                    (Rendition.View.progress r p)
                                ]
                        )
                        rendition
                        channel.playing

        control =
            if model.showChannelControl then
                (channelControl model channel)
            else
                div [] []
    in
        div
            [ classList
                [ ("root--channel-control-bar", True)
                , ("root--channel-control-bar__inactive", not model.showChannelControl)
                , ("root--channel-control-bar__active", model.showChannelControl)
                ]
            ]
            [
                div
                    [ class "root--channel-control-position" ]
                    [ div
                        [ class "root--active-rendition" ]
                        [ (rendition model channel)
                        , Html.map (Msg.Channel channel.id) progress
                        ]
                    , control
                    ]
            ]


rendition : Root.Model -> Channel.Model -> Html Msg
rendition model channel =
    let
        maybeRendition =
            List.head channel.playlist

        rendition =
            case maybeRendition of
                Nothing ->
                    div [] [ text "No song..." ]

                Just rendition ->
                    div [ class "channel--rendition" ]
                        [ Html.map (always Msg.NoOp) (Rendition.View.info rendition channel.playing)
                        ]

        mapTap a =
            Html.Attributes.map Msg.SingleTouch a
    in
        div
            [ class "channel--playback"
            , onClick Msg.ToggleShowChannelControl
            , mapTap (Utils.Touch.touchStart Msg.ToggleShowChannelControl)
            , mapTap (Utils.Touch.touchEnd Msg.ToggleShowChannelControl)
            ]
            [ div
                [ class "channel--info" ]
                [ div
                    [ class "channel--info--name" ]
                    [ div
                        [ class "channel--name" ]
                        [ text channel.name
                        , span
                            [ class "channel--playlist-duration" ]
                            [ lazy playlistDuration channel ]
                        ]
                    ]
                , rendition
                ]
            ]



activeView : Root.Model -> Channel.Model -> Html Msg
activeView model channel =
    let
        view =
            case model.viewMode of
                State.ViewCurrentChannel ->
                    Html.map (Msg.Channel channel.id) (lazy Channel.View.playlist channel)

                State.ViewLibrary ->
                    Html.map Msg.Library (Library.View.root model.library)

                State.ViewSettings ->
                    Settings.View.application model.settings
    in
        div
            [ class "root--active-view" ]
            [ view ]


switchView : Root.Model -> Channel.Model -> Html Msg
switchView model channel =
    let
        states =
            (List.map (switchViewButton model channel) State.viewModes)

        switchChannel =
            div
                [ classList
                    [ ( "root--switch-view--btn", True )
                    , ( "root--switch-view--btn__active", model.showSelectChannel )
                    , ( "root--switch-view--btn__SelectChannel", True )
                    ]
                , onClick (Msg.ToggleShowChannelSelector)
                , mapTouch (Utils.Touch.touchStart (Msg.ToggleShowChannelSelector))
                , mapTouch (Utils.Touch.touchEnd (Msg.ToggleShowChannelSelector))
                ]
                [ text "Channels" ]
    in
        div
            [ class "root--switch-view" ]
            (switchChannel :: states)


playlistDuration : Channel.Model -> Html Msg
playlistDuration channel =
    text
        <| Source.View.durationString
            <| (Channel.playlistDuration channel)

switchViewButton : Root.Model -> Channel.Model -> State.ViewMode -> Html Msg
switchViewButton model channel mode =
    let
        label =
            case mode of
                State.ViewCurrentChannel ->
                    span
                        []
                        [ text ((State.viewLabel State.ViewCurrentChannel))
                        , span [ class "channel--playlist-duration" ] [ lazy playlistDuration channel ]
                        ]

                m ->
                    text (State.viewLabel m)
    in
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
            [ label ]


mapTouch : Attribute (Utils.Touch.E Msg) -> Attribute Msg
mapTouch a =
    Html.Attributes.map Msg.SingleTouch a


notifications : Root.Model -> Html Msg
notifications model =
    div
        [ class "root--notifications" ]
        [ (Notification.View.notifications model.animationTime model.notifications)
        ]


channelControl : Root.Model -> Channel.Model -> Html Msg
channelControl model channel =
    let
        contents =
            case model.showChannelControl of
                False ->
                    []

                True ->
                    [ (Html.map
                        (Msg.Channel channel.id)
                        (Channel.View.control model channel)
                      )
                    , Channels.View.channelReceivers model channel
                    -- padding
                    , (div [ style [("height", "30vh")] ] [])
                    ]

    in
        div
            [ classList
                [ ("root--channel-control", True)
                , ("root--channel-control__active", model.showChannelControl)
                , ("scrolling", True)
                ]
            ]
            contents


