module Channels.View exposing (channels, cover, playlist)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.App exposing (map)
import Debug
import Json.Decode as Json

import Root
import Root.State
import Channels
import Channels.State
import Receivers
import Receivers.State
import Receivers.View
import Channel
import Channel.View
import Volume.View
import Library.View
import Input
import Input.View
import Source.View
import Msg exposing (Msg)


channels : Channels.Model -> Receivers.Model -> Html Msg
channels channels receivers =
  case Channels.State.activeChannel channels of
    Nothing ->
      div [] []

    Just activeChannel ->
      channelsBar channels receivers activeChannel


channelsBar : Channels.Model -> Receivers.Model -> Channel.Model -> Html Msg
channelsBar channels receivers activeChannel =
  let

    options =
      { defaultOptions | preventDefault = True }

    -- onTouch =
    --   onWithOptions "touchend" options Json.value (\_ -> (Channels.ToggleSelector))
  in
    div
      [ classList [ ( "channels", True ), ( "channels__select-channel", channels.showChannelSwitcher ) ] ]
      [ div
          [ class "channels--bar" ]
          [ (channelSettingsButton)
          , (currentChannelPlayer activeChannel)
          ]
      , (channelSelectorPanel channels receivers activeChannel)
      ]


channelSettingsButton : Html Msg
channelSettingsButton =
  div
    [ class "channels--channel-select", onClick (Channels.ToggleSelector) {- , onTouch -} ]
    [ i [ class "fa fa-bullseye" ] [] ]


currentChannelPlayer :  Channel.Model -> Html Msg
currentChannelPlayer channel =
    map (Msg.Channels (Channels.Modify channel.id)) (Channel.View.player channel)


channelSelectorPanel : Channels.Model -> Receivers.Model -> Channel.Model -> Html Msg
channelSelectorPanel channels receivers activeChannel =
  let
    -- unselectedChannels =
    --   List.filter (\channel -> channel.id /= activeChannel.id) channels.channels
    channelSummaries =
      List.map (Channel.summary receivers.receivers) channels.channels

    (activeChannels, inactiveChannels) =
      List.partition Channel.isActive channelSummaries

    orderChannels summaries =
      List.sortBy (\c -> c.channel.originalName) summaries

  in
    case channels.showChannelSwitcher of
      False ->
        div [] []

      True ->
        div
          [ class "channels--overlay" ]
          [ div
              [ class "channels--channel-control" ]
              [ map
                  (\m -> (Channels.Modify activeChannel.id) (Channel.Volume m))
                  (Volume.View.control activeChannel.volume
                    (div [ class "channel--name" ] [ text activeChannel.name ])
                  )
              , map Channels.ModifyReceivers (Receivers.View.receivers receivers activeChannel)
              ]
          , div
              [ class "channels--header" ]
              [ div
                  [ class "channels--title" ]
                  [ text (((toString (List.length channels.channels)) ++ " Channels"))]
              , div
                  [ classList
                    [ ("channels--add-btn", True)
                    , ("channels--add-btn__active", channels.showAddChannel)
                    ]
                  , onClick Channels.ToggleAdd
                  ]
                  []
              ]
          , addChannelPanel channels
          , div
              [ class "channels-selector" ]
              [ div
                  [ class "channels-selector--list" ]
                  [ div [ class "channels-selector--separator" ] [ text "Active" ]
                  , div [ class "channels-selector--group" ] (List.map (channelChoice receivers activeChannel) (orderChannels activeChannels))
                  , div [ class "channels-selector--separator" ] [ text "Inactive" ]
                  , div [ class "channels-selector--group" ] (List.map (channelChoice receivers activeChannel) (orderChannels inactiveChannels))
                  ]
              ]
          ]

addChannelPanel : Channels.Model -> Html Msg
addChannelPanel model =
    case model.showAddChannel of
      False ->
        div [] []

      True ->
        map Channels.AddInput ( Input.View.inputSubmitCancel model.newChannelInput )



channelChoice : Receivers.Model -> Channel.Model -> Channel.Summary -> Html Msg
channelChoice receivers activeChannel channelSummary =
  let
    channel = channelSummary.channel

    duration =
      case channelSummary.playlistDuration of
        Nothing ->
          ""

        Just 0 ->
          ""

        time ->
          Source.View.durationString time

    onClickChoose =
      onClick (Channels.Choose channel)

    onClickEdit =
      onWithOptions
        "click"
        { defaultOptions | stopPropagation = True }
        (Json.succeed (Channels.Modify channelSummary.id (Channel.ShowEditName True)))

    -- options = { defaultOptions | preventDefault = True }
    -- this kinda works, but it triggered even after a scroll...
    -- onTouchChoose =
    --   onWithOptions "touchend" options Json.value (\_ -> (Channels.Choose channel))

    editNameInput =
      case channel.editName of
        False ->
          map Channel.EditName (div [] [])

        True ->
          map Channel.EditName (Input.View.inputSubmitCancel channel.editNameInput)
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
          [ map (Channels.Modify channel.id) editNameInput ]
      ]


cover : Channel.Model -> Html Msg
cover channel =
  map (Channels.Modify channel.id) (Channel.View.cover channel)


playlist : Channels.Model -> Html Msg
playlist model =
  let
    playlist =
      case Channels.State.activeChannel model of
        Nothing ->
          div [] []

        Just channel ->
          map (Channels.Modify channel.id) (Channel.View.playlist channel)

  in
    playlist
