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
import Animation
import Time


loadingAnimation : String -> Time.Time -> Html Msg
loadingAnimation message time =
    div
        [ class "root--loading__message" ]
        [ (Spinner.ripple (round <| Time.inMilliseconds <| time))
        , text message
        ]


root : Root.Model -> Html Msg
root model =
    case model.connected of
        True ->
            rootWhenConnected model

        False ->
            let
                spinner time =
                    loadingAnimation "Connecting" time
            in
                div
                    [ class "root--loading" ]
                    [ lazy spinner model.startTime
                    ]


rootWhenConnected : Root.Model -> Html Msg
rootWhenConnected model =
    case (Root.State.activeChannel model) of
        Nothing ->
            let
                spinner time =
                    loadingAnimation "Loading" time
            in
                div
                    [ class "root--loading" ]
                    [ lazy spinner model.startTime
                    ]

        Just channel ->
            rootWithActiveChannel model channel


rootWithActiveChannel : Root.Model -> Channel.Model -> Html Msg
rootWithActiveChannel model channel =
    div
        [ id "root"
        , classList
            [ ( "root--channel-select__active", model.showSelectChannel )
            , ( "root--channel-select__inactive", not model.showSelectChannel )
            , ( "root--channel-control__active", showChannelControl model )
            , ( "root--channel-control__inactive", not <| showChannelControl model )
            ]
        ]
        [ (selectChannel model channel)
        , (channelView model channel)
        ]


selectChannel : Root.Model -> Channel.Model -> Html Msg
selectChannel model channel =
    let
        shown =
            model.showSelectChannel
                || (Animation.isRunning model.animationTime model.viewAnimations.revealChannelList)
    in
        case shown of
            True ->
                div [ class "root--channel-list" ]
                    [ div
                        []
                        [ Channels.View.channelSelector model channel ]
                    ]

            False ->
                div [ class "root--channel-list" ] []


channelView : Root.Model -> Channel.Model -> Html Msg
channelView model channel =
    let
        position =
            (Animation.animate model.animationTime model.viewAnimations.revealChannelList)

        left =
            "calc(" ++ (toString position) ++ " * (100vw - 85px))"
    in
        div
            [ class "root--channel", style [ ( "left", left ) ] ]
            [ (switchView model channel)
            , (notifications model)
            , (activeView model channel)
            , (activeRendition model channel)
            , channelViewOverlay
            ]


channelViewOverlay : Html Msg
channelViewOverlay =
    div
        [ class "root--channel-list-toggle"
        , onClick (Msg.ToggleShowChannelSelector)
        , mapTouch (Utils.Touch.touchStart (Msg.ToggleShowChannelSelector))
        , mapTouch (Utils.Touch.touchEnd (Msg.ToggleShowChannelSelector))
        ]
        []


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

        shown =
            showChannelControl model

        styles =
            if shown then
                let
                    position =
                        Animation.animate model.animationTime model.viewAnimations.revealChannelControl

                    top =
                        "calc(" ++ (toString position) ++ " * (100vh - 55px))"
                in
                    [ ( "top", top ) ]
            else
                []

        control =
            if shown then
                (channelControl model channel shown)
            else
                div [] []
    in
        div
            [ classList
                [ ( "root--channel-control-bar", True )
                , ( "root--channel-control-bar__inactive", not shown )
                , ( "root--channel-control-bar__active", shown )
                ]
            ]
            [ div
                [ class "root--channel-control-position", style styles ]
                [ div
                    [ class "root--active-rendition" ]
                    [ (rendition model channel)
                    , Html.map (Msg.Channel channel.id) progress
                    ]
                , control
                ]
            ]


showChannelControl : Root.Model -> Bool
showChannelControl model =
    model.showChannelControl
        || (Animation.isRunning model.animationTime model.viewAnimations.revealChannelControl)


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
                    Settings.View.configure model
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
    text <|
        Source.View.durationString <|
            (Channel.playlistDuration channel)


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
                , ( "root--switch-view--btn__" ++ (toString mode), True )
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


channelControl : Root.Model -> Channel.Model -> Bool -> Html Msg
channelControl model channel visible =
    let
        contents =
            case visible of
                False ->
                    []

                True ->
                    [ (Html.map
                        (Msg.Channel channel.id)
                        (Channel.View.control model channel)
                      )
                    , Channels.View.channelReceivers model channel
                      -- padding
                    , (div [ style [ ( "height", "30vh" ) ] ] [])
                    ]
    in
        div
            [ classList
                [ ( "root--channel-control", True )
                , ( "root--channel-control__active", visible )
                , ( "scrolling", True )
                ]
            ]
            contents
