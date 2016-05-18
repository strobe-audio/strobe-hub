module Channels.View (channels, cover, playlist) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
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


channels : Signal.Address Channels.Action -> Channels.Model -> Signal.Address Receivers.Action -> Receivers.Model -> Html
channels address channels receiversAddress receivers =
  case Channels.State.activeChannel channels of
    Nothing ->
      div [] []

    Just activeChannel ->
      channelsBar address channels receiversAddress receivers activeChannel


channelsBar : Signal.Address Channels.Action -> Channels.Model -> Signal.Address Receivers.Action -> Receivers.Model -> Channel.Model -> Html
channelsBar address channels receiversAddress receivers activeChannel =
  let
    channelAddress =
      Signal.forwardTo address (Channels.Modify activeChannel.id)

    options =
      { defaultOptions | preventDefault = True }

    -- onTouch =
    --   onWithOptions "touchend" options Json.value (\_ -> Signal.message address (Channels.ToggleSelector))
  in
    div
      [ classList [ ( "channels", True ), ( "channels__select-channel", channels.showChannelSwitcher ) ] ]
      [ div
          [ class "channels--bar" ]
          [ (channelSettingsButton address)
          , (currentChannelPlayer address activeChannel)
          ]
      , (channelSelectorPanel address channels receiversAddress receivers activeChannel)
      ]


channelSettingsButton : Signal.Address Channels.Action -> Html
channelSettingsButton address =
  div
    [ class "channels--channel-select", onClick address (Channels.ToggleSelector) {- , onTouch -} ]
    [ i [ class "fa fa-bullseye" ] [] ]


currentChannelPlayer : Signal.Address Channels.Action -> Channel.Model -> Html
currentChannelPlayer address channel =
  let
    playerAddress =
      Signal.forwardTo address (Channels.Modify channel.id)
  in
    Channel.View.player playerAddress channel


channelSelectorPanel : Signal.Address Channels.Action -> Channels.Model -> Signal.Address Receivers.Action -> Receivers.Model -> Channel.Model -> Html
channelSelectorPanel address channels receiversAddress receivers activeChannel =
  let
    -- unselectedChannels =
    --   List.filter (\channel -> channel.id /= activeChannel.id) channels.channels
    channelSummaries =
      List.map (Channel.summary receivers.receivers) channels.channels

    (activeChannels, inactiveChannels) =
      List.partition Channel.isActive channelSummaries

    orderChannels summaries =
      List.sortBy (\c -> c.channel.originalName) summaries

    channelAddress =
      Signal.forwardTo address (Channels.Modify activeChannel.id)

    volumeAddress =
      Signal.forwardTo channelAddress Channel.Volume

  in
    case channels.showChannelSwitcher of
      False ->
        div [] []

      True ->
        div
          [ class "channels--overlay" ]
          [ div
              [ class "channels--channel-control" ]
              [ (Volume.View.control volumeAddress activeChannel.volume (div [ class "channel--name" ] [ text activeChannel.name ]))
              , Receivers.View.receivers receiversAddress receivers activeChannel
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
                  , onClick address Channels.ToggleAdd
                  ]
                  []
              ]
          , addChannelPanel address channels
          , div
              [ class "channels-selector" ]
              [ div
                  [ class "channels-selector--list" ]
                  [ div [ class "channels-selector--separator" ] [ text "Active" ]
                  , div [ class "channels-selector--group" ] (List.map (channelChoice address receivers activeChannel) (orderChannels activeChannels))
                  , div [ class "channels-selector--separator" ] [ text "Inactive" ]
                  , div [ class "channels-selector--group" ] (List.map (channelChoice address receivers activeChannel) (orderChannels inactiveChannels))
                  ]
              ]
          ]

addChannelPanel : Signal.Address Channels.Action -> Channels.Model -> Html
addChannelPanel address model =
  let
    context =
      { address = Signal.forwardTo address Channels.NewInput
      , cancelAddress = Signal.forwardTo address (always Channels.ToggleAdd)
      , submitAddress = Signal.forwardTo address Channels.Add
      }
  in
    case model.showAddChannel of
      False ->
        div [] []
        -- div
        --   [ class "channel-selector--add", onClick address (Channels.ToggleAdd) ]
        --   [ text "Add new channel..." ]

      True ->
        Input.View.inputSubmitCancel context model.newChannelInput



channelChoice : Signal.Address Channels.Action -> Receivers.Model -> Channel.Model -> Channel.Summary -> Html
channelChoice address receivers activeChannel channelSummary =
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
      onClick address (Channels.Choose channel)

    onClickEdit =
      onWithOptions
        "click"
        { defaultOptions | stopPropagation = True }
        Json.value
        (\_ ->
          Signal.message address (Channels.Modify channelSummary.id (Channel.ShowEditName True))
        )

    -- options = { defaultOptions | preventDefault = True }
    -- this kinda works, but it triggered even after a scroll...
    -- onTouchChoose =
    --   onWithOptions "touchend" options Json.value (\_ -> Signal.message address (Channels.Choose channel))
    channelAddress =
      Signal.forwardTo address (Channels.Modify channelSummary.id)

    editNameInput =
      case channel.editName of
        False ->
          div [] []

        True ->
          let
            context =
              { address = Signal.forwardTo channelAddress Channel.EditName
              , cancelAddress = Signal.forwardTo channelAddress (always (Channel.ShowEditName False))
              , submitAddress = Signal.forwardTo channelAddress Channel.Rename
              }
          in
            Input.View.inputSubmitCancel context channel.editNameInput
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
            -- , div [ class "channels-selector--channel--edit", onClick address (Channels.Modify channel.id (Channel.ShowEditName True)) ] []
          ]
      , div
          [ classList
              [ ( "channels-selector--edit", True )
              , ( "channels-selector--edit__active", channel.editName )
              ]
          ]
          [ editNameInput ]
      ]


cover : Signal.Address Channels.Action -> Channel.Model -> Html
cover address channel =
  let
    playerAddress =
      Signal.forwardTo address (Channels.Modify channel.id)
  in
    Channel.View.cover playerAddress channel


playlist : Signal.Address Channels.Action -> Channels.Model -> Html
playlist address model =
  let
    playlist =
      case Channels.State.activeChannel model of
        Nothing ->
          div [] []

        Just channel ->
          Channel.View.playlist (Signal.forwardTo address (Channels.Modify channel.id)) channel
  in
    playlist
