module Channels.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html
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


channels : Root.Model -> Html Msg
channels model =
    case Root.activeChannel model of
        Nothing ->
            div [] []

        Just channel ->
            channelsBar model channel


channelsBar : Root.Model -> Channel.Model -> Html Msg
channelsBar model activeChannel =
    let
        options =
            { defaultOptions | preventDefault = True }

        -- onTouch =
        --   onWithOptions "touchend" options Json.value (\_ -> (Channels.ToggleSelector))
    in
        div [ classList [ ( "channels", True ), ( "channels__select-channel", model.showChannelSwitcher ) ] ]
            [ (channelSelectorPanel model activeChannel)
            ]




channelSelectorPanel : Root.Model -> Channel.Model -> Html Msg
channelSelectorPanel model activeChannel =
    let
        channels =
            model.channels

        receivers =
            model.receivers

        -- unselectedChannels =
        --   List.filter (\channel -> channel.id /= activeChannel.id) channels.channels
        channelSummaries =
            List.map (Channel.summary receivers) channels

        ( activeChannels, inactiveChannels ) =
            List.partition Channel.isActive channelSummaries

        orderChannels summaries =
            List.sortBy (\c -> c.channel.originalName) summaries

        volumeCtrl =
            (Volume.View.control activeChannel.volume
                (div [ class "channel--name" ] [ text activeChannel.name ])
            )
    in
        case model.showChannelSwitcher of
            False ->
                div [] []

            True ->
                div [ class "channels--overlay" ]
                    [ div
                        [class "channels--view"]
                    [ div [ class "channels--channel-control" ]
                        [ Html.map (\m -> (Msg.Channel activeChannel.id) (Channel.Volume m)) volumeCtrl
                        , (Receivers.View.receivers model activeChannel)
                        ]
                    , div [ class "channels--header" ]
                        [ div [ class "channels--title" ]
                            [ text (((toString (List.length channels)) ++ " Channels")) ]
                        , div
                            [ classList
                                [ ( "channels--add-btn", True )
                                , ( "channels--add-btn__active", model.showAddChannel )
                                ]
                            , onClick Msg.ToggleAddChannel
                            ]
                            []
                        ]
                    , addChannelPanel model
                    , div [ class "channels-selector" ]
                        [ div [ class "channels-selector--list" ]
                            [ div [ class "channels-selector--separator" ] [ text "Active" ]
                            , div [ class "channels-selector--group" ] (List.map (channelChoice receivers activeChannel) (orderChannels activeChannels))
                            , div [ class "channels-selector--separator" ] [ text "Inactive" ]
                            , div [ class "channels-selector--group" ] (List.map (channelChoice receivers activeChannel) (orderChannels inactiveChannels))
                            ]
                        ]
                    ]
                    , div [ class "channels--toggle", onMouseDown Msg.ToggleChannelSelector ] []
                    ]


addChannelPanel : Root.Model -> Html Msg
addChannelPanel model =
    case model.showAddChannel of
        False ->
            div [] []

        True ->
            Html.map Msg.AddChannelInput (Input.View.inputSubmitCancel model.newChannelInput)


channelChoice : List Receiver.Model -> Channel.Model -> Channel.Summary -> Html Msg
channelChoice receivers activeChannel channelSummary =
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

        onClickChoose =
            onClick (Msg.ActivateChannel channel)

        onClickEdit =
            onWithOptions "click"
                { defaultOptions | stopPropagation = True }
                (Json.succeed (Msg.Channel channelSummary.id (Channel.ShowEditName True)))

        -- options = { defaultOptions | preventDefault = True }
        -- this kinda works, but it triggered even after a scroll...
        -- onTouchChoose =
        --   onWithOptions "touchend" options Json.value (\_ -> (Channels.Choose channel))
        editNameInput =
            case channel.editName of
                False ->
                    div [] []

                True ->
                    Input.View.inputSubmitCancel channel.editNameInput
    in
        div
            [ classList
                [ ( "channels-selector--channel", True )
                , ( "channels-selector--channel__active", channelSummary.id == activeChannel.id )
                , ( "channels-selector--channel__playing", channel.playing )
                , ( "channels-selector--channel__edit", channel.editName )
                ]
            ]
            [ div
                [ classList
                    [ ( "channels-selector--display", True )
                    , ( "channels-selector--display__inactive", channel.editName )
                    ]
                , onClickChoose
                ]
                [ div [ class "channels-selector--channel--name", onClickChoose ] [ text channel.name ]
                , div [ class "channels-selector--channel--duration duration", onClickChoose ] [ text duration ]
                , div
                    [ classList
                        [ ( "channels-selector--channel--receivers", True )
                        , ( "channels-selector--channel--receivers__empty", channelSummary.receiverCount == 0 )
                        ]
                    , onClickChoose
                    ]
                    [ text (toString channelSummary.receiverCount) ]
                , div [ class "channels-selector--channel--edit", onClickEdit ] []
                ]
            , div
                [ classList
                    [ ( "channels-selector--edit", True )
                    , ( "channels-selector--edit__active", channel.editName )
                    ]
                ]
                [ Html.map (\e -> Msg.Channel channel.id (Channel.EditName e)) editNameInput ]
            ]


cover : Channel.Model -> Html Msg
cover channel =
    Html.map (Msg.Channel channel.id) (Channel.View.cover channel)


playlist : Channel.Model -> Html Msg
playlist channel =
    Html.map (Msg.Channel channel.id) (Channel.View.playlist channel)
