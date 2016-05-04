module Channel.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug
import Root
import Channel
import Channel.State
import Rendition
import Rendition.View
import Receiver
import Receiver.View


root : Root.ChannelContext -> Channel.Model -> Bool -> Html
root context channel playlistVisible =
  let
    rendition =
      List.head channel.playlist

    playPauseAddress =
      Signal.forwardTo context.channelAddress (always Channel.PlayPause)

    renditions =
      case playlistVisible of
        True ->
          div
            []
            [ (receiverList context channel)
            , (playlist context channel)
            ]

        False ->
          div [] []
  in
    div
      []
      [ (playingSong playPauseAddress channel rendition)
      , renditions
      ]


playingSong : Signal.Address () -> Channel.Model -> Maybe Rendition.Model -> Html
playingSong address channel maybeRendition =
  case maybeRendition of
    Nothing ->
      div [] [ text "No song..." ]

    Just rendition ->
      div
        []
        [ (Rendition.View.playing address rendition)
        , (Rendition.View.progress address rendition)
        ]


receiverList : Root.ChannelContext -> Channel.Model -> Html
receiverList context channel =
  let
    addButton =
      case List.length context.detached of
        0 ->
          []

        _ ->
          if channel.showAddReceiver then
            [ div
                [ class "channel-receivers--add", onClick context.channelAddress (Channel.ShowAddReceiver False) ]
                [ i [ class "fa fa-caret-up" ] [] ]
            ]
          else
            [ div
                [ class "channel-receivers--add", onClick context.channelAddress (Channel.ShowAddReceiver True) ]
                [ i [ class "fa fa-plus" ] [] ]
            ]

    attachList =
      case channel.showAddReceiver of
        False ->
          div [] []

        True ->
          (attachReceiverList context channel context.detached)

    attachedReceiver receiver =
      (Receiver.View.attached (context.receiverAddress receiver) receiver)

    attachedReceivers =
      Receiver.sort context.attached
  in
    div
      [ class "channel-receivers" ]
      [ div [ class "channel-receivers--head" ] ((div [ class "block divider" ] [ text "Receivers" ]) :: addButton)
      , attachList
      , div [ class "channel-receivers--list" ] (List.map attachedReceiver attachedReceivers)
      ]


attachReceiverList : Root.ChannelContext -> Channel.Model -> List Receiver.Model -> Html
attachReceiverList context channel receivers =
  let
    sortedReceivers =
      (Receiver.sort receivers)
  in
    div [ class "channel-receivers--available" ] (List.map (attachReceiverEntry context channel) sortedReceivers)


attachReceiverEntry : Root.ChannelContext -> Channel.Model -> Receiver.Model -> Html
attachReceiverEntry context channel receiver =
  Receiver.View.attach (context.receiverAddress receiver) channel receiver


playlist : Root.ChannelContext -> Channel.Model -> Html
playlist context channel =
  let
    entry rendition =
      let
        renditionAddress =
          Signal.forwardTo context.channelAddress (Channel.ModifyRendition rendition.id)
      in
        Rendition.View.playlist renditionAddress rendition

    playlist =
      Maybe.withDefault [] (List.tail channel.playlist)
  in
    div
      [ class "channel-playlist" ]
      [ div [ class "divider" ] [ text "Playlist" ]
      , div
          [ class "block-group channel-playlist" ]
          (List.map entry playlist)
      ]
