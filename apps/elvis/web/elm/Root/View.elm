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
            , (channelControl model channel)
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
                            (always Channel.NoOp)
                            (Rendition.View.progress rendition channel.playing)
                        ]

    in
        div [ class "root--active-rendition" ]
            [ (rendition model channel)
            , Html.map (Msg.Channel channel.id) progress
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
                            [ text
                                <| Source.View.durationString
                                <| (Channel.playlistDuration channel)
                            ]
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
                    , (receiverControl model channel)
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


receiverControl : Root.Model -> Channel.Model -> Html Msg
receiverControl model channel =
    let
        hideAttachMsg =
            Msg.ShowAttachReceiver False

        ( attached, detached ) =
            Receiver.partitionReceivers model.receivers channel

        contents =
            case model.showAttachReceiver of
                True ->
                    Channels.View.detachedReceivers model channel

                False ->
                    Channels.View.channelReceivers model channel

        showAttachMsg =
            if List.isEmpty detached then
                Msg.NoOp

            else
                Msg.ShowAttachReceiver True

    in
        div
            [ class "root--receiver-control" ]
            [ div
                [ class "root--receiver-control-tabs" ]
                [ div
                    [ classList
                        [ ("root--receiver-control-tab", True )
                        , ("root--receiver-control-tab__active", not model.showAttachReceiver )
                        , ("root--receiver-control--attached", True )
                        ]
                    , onClick hideAttachMsg
                    , mapTouch (Utils.Touch.touchStart hideAttachMsg)
                    , mapTouch (Utils.Touch.touchEnd hideAttachMsg)
                    ]
                    [ text ((toString (List.length attached)) ++ " Receivers")
                    ]
                , div
                    [ classList
                        [ ("root--receiver-control-tab", True )
                        , ("root--receiver-control-tab__active", model.showAttachReceiver )
                        , ("root--receiver-control--detached", True )
                        , ("root--receiver-control-tab__disabled", (List.isEmpty detached) )
                        ]
                    , onClick showAttachMsg
                    , mapTouch (Utils.Touch.touchStart showAttachMsg)
                    , mapTouch (Utils.Touch.touchEnd showAttachMsg)
                    ]
                    [ text "Attach"
                    ]
                ]
            , contents
            ]
