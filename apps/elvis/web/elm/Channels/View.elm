module Channels.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html
import Html.Lazy exposing (lazy)
import Json.Decode as Json
import Debug


--

import Root
import Root.State
import Receiver
import Receivers.View
import Channel
import Channel.View
import Volume.View
import Library.View
import Input
import Input.View
import Source.View
import Msg exposing (Msg)
import Utils.Touch exposing (onUnifiedClick, onSingleTouch)


channelSelector : Root.Model -> Channel.Model -> Html Msg
channelSelector model channel =
    div
        [ classList
            [ ( "channels--view", True )
            ]
        ]
        [ (changeChannel model channel)
        ]


channelReceivers : Root.Model -> Channel.Model -> Html Msg
channelReceivers model channel =
    div
        [ class "channels--receivers channel--receivers__attached" ]
        [ Receivers.View.attached model channel ]


detachedReceivers : Root.Model -> Channel.Model -> Html Msg
detachedReceivers model channel =
    div
        [ class "channels--receivers channel--receivers__detached" ]
        [ Receivers.View.detached model channel ]


channelVolume : Root.Model -> Channel.Model -> Html Msg
channelVolume model channel =
    let
        volumeCtrl =
            (Volume.View.control channel.volume
                False
                (text "Master volume")
            )
    in
        div
            [ class "channels--channel-control" ]
            [ Html.map (\m -> (Msg.Channel channel.id) (Channel.Volume m)) volumeCtrl
            ]


changeChannel : Root.Model -> Channel.Model -> Html Msg
changeChannel model activeChannel =
    let
        channels =
            model.channels

        receivers =
            model.receivers

        channelSummaries =
            List.map (Channel.summary receivers) channels

        orderChannels summaries =
            List.sortBy (\c -> c.channel.id) summaries
    in
        div [ class "channels-selector" ]
            [ div [ class "channels-selector--list" ]
                [ div
                    [ class "channels-selector--group" ]
                    (List.map (channelChoice model receivers activeChannel) (orderChannels channelSummaries))
                ]
            ]


channelChoice : Root.Model -> List Receiver.Model -> Channel.Model -> Channel.Summary -> Html Msg
channelChoice model receivers activeChannel channelSummary =
    let
        channel =
            channelSummary.channel

        duration =
            case channelSummary.playlistDuration of
                Nothing ->
                    ""

                Just 0 ->
                    ""

                time ->
                    Source.View.durationString time

        msg =
            (Msg.ActivateChannel channel)

        isActive =
            channelSummary.id == activeChannel.id

        receiverAttachList =
            if isActive then
                div [ class "channels-selector--channel-attach-receivers" ]
                    [ Receivers.View.detached model activeChannel ]
            else
                div [] []

        channelVolumeControl =
            if isActive then
                Html.map
                    (\m -> (Msg.Channel channel.id) (Channel.Volume m))
                    (Volume.View.bareControl channel.volume)
            else
                div [] []
    in
        div
            [ classList
                [ ( "channels-selector--channel", True )
                , ( "channels-selector--channel__active", isActive )
                , ( "channels-selector--channel__playing", channel.playing )
                , ( "channels-selector--channel__edit", channel.editName )
                ]
            ]
            [ div
                [ class "channels-selector--display" ]
                [ div
                    [ classList
                        [ ( "channels-selector--channel--play-pause", True )
                        , ( "channels-selector--channel--play-pause__play", channel.playing )
                        , ( "channels-selector--channel--play-pause__pause", not channel.playing )
                        ]
                    ]
                    [ channelPlayPauseBtn model channel ]
                , div
                    [ class "channels-selector--channel-info"
                    , mapTouch (Utils.Touch.touchStart msg)
                    , mapTouch (Utils.Touch.touchEnd msg)
                    , onClick msg
                    ]
                    [ div [ class "channels-selector--channel--name" ] [ text channel.name ]
                    , div [ class "channels-selector--channel--duration duration" ] [ text duration ]
                    , div
                        [ classList
                            [ ( "channels-selector--channel--receivers", True )
                            , ( "channels-selector--channel--receivers__empty", channelSummary.receiverCount == 0 )
                            ]
                        ]
                        [ text (toString channelSummary.receiverCount) ]
                    ]
                ]
            , channelVolumeControl
            , receiverAttachList
            ]


channelPlayPauseBtn : Root.Model -> Channel.Model -> Html Msg
channelPlayPauseBtn model channel =
    Html.map (Msg.Channel channel.id) (Channel.View.playPauseButton channel)


mapTouch : Attribute (Utils.Touch.E Msg) -> Attribute Msg
mapTouch a =
    Html.Attributes.map Msg.SingleTouch a
