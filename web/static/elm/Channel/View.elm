module Channel.View where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Debug

import Types exposing (..)
import Channel
import Rendition
import Rendition.View
import Receiver.View
import Receiver


root : Signal.Address Channel.Action -> Model -> Channel.Model -> Html
root address model channel =
  let
      rendition = List.head channel.playlist
      playPauseAddress = Signal.forwardTo address (always Channel.PlayPause)
  in
    div []
      [ (playingSong playPauseAddress channel rendition)
      , (receiverList address model channel)
      , (playlist address model channel)
      ]


playingSong : Signal.Address () -> Channel.Model -> Maybe Rendition.Model -> Html
playingSong address channel maybeRendition =
  case maybeRendition of
    Nothing ->
      div [] [ text "No song..." ]
    Just rendition ->
      div [] [
        (Rendition.View.playing address rendition)
      , (Rendition.View.progress address rendition)
      ]


receiverList : Signal.Address Channel.Action -> Model -> Channel.Model -> Html
receiverList address model channel =
  let
      attached = Debug.log "receivers" channel.receivers
      detached = Debug.log "detached" (receiversNotAttachedToChannel model channel)
      showAdd = Debug.log "show add" channel.showAddReceiver
      addButton = case List.length detached of
        0 ->
          []
        _ ->
          if showAdd then
            [ div [ class "block channel-receivers--add", onClick address (Channel.ShowAddReceiver False) ]
              [ i [ class "fa fa-caret-up" ] [] ]
            ]
          else
            [ div [ class "block channel-receivers--add", onClick address (Channel.ShowAddReceiver True) ]
              [ i [ class "fa fa-plus" ] [] ]
            ]
      -- FIXME: the receiver address needs an id and so is per-receiver
      receiverAddress = Signal.forwardTo address Channel.ModifyReceiver
      receiverList = case showAdd of
        False ->
          div [] []
        True ->
          attachReceiverList receiverAddress channel detached

  in
     div [ class "channel-receivers" ] [
       div [ class "block-group channel-receivers--head" ] ( (div [ class "block divider" ] [ text "Receivers" ]) :: addButton )
     , receiverList
     , div [ class "channel-receivers--list" ] (List.map (Receiver.View.attached receiverAddress) attached)
     ]



receiversNotAttachedToChannel : Model -> Channel.Model -> List Receiver.Model
receiversNotAttachedToChannel model channel =
  let
      receivers = List.map (\c -> c.receivers) model.channels |> List.concat
  in
      List.filter (\r -> r.zoneId /= channel.id) receivers


attachReceiverList : Signal.Address Receiver.Action -> Channel.Model -> List Receiver.Model -> Html
attachReceiverList address channel receivers =
    div [ class "channel-receivers--available" ] (List.map (attachReceiverEntry address channel) receivers)


attachReceiverEntry : Signal.Address Receiver.Action -> Channel.Model -> Receiver.Model -> Html
attachReceiverEntry address channel receiver =
  let
      receiverAddress =  Receiver.Attach channel.id
  in
      div [ class "channel-receivers--available-receiver" ]
        [ div
          [ class "channel-receivers--add-receiver"
          , onClick address receiverAddress
          ]
          [ text receiver.name ]
        , div [ class "channel-receivers--edit-receiver" ]
            [ i [ class "fa fa-pencil" ] [] ]
        ]


playlist : Signal.Address Channel.Action -> Model -> Channel.Model -> Html
playlist address model channel =
  let
      entry rendition =
        let
            renditionAddress = Signal.forwardTo address (Channel.ModifyRendition rendition.id)
        in
            Rendition.View.playlist renditionAddress rendition
  in
  div [ class "channel-playlist" ]
      [ div [ class "divider" ] [ text "Playlist" ]
      , div [ class "block-group channel-playlist" ]
          (List.map entry channel.playlist)
      ]


-- zoneModePanel : Signal.Address Action -> Model -> List Html
-- zoneModePanel address model =
--   case activeZone model of
--     Nothing ->
--       []
--     Just zone ->
--       let
--         playlist = (zonePlaylist model zone)
--         playlistdebug = (List.map (\e -> e.id) playlist.entries)
--       in
--         [ zoneReceiverList address model zone
--         , div [ class "divider" ] [ text "Playlist" ]
--         , div [ class "block-group channel-playlist" ] (List.map (playlistEntry address)  playlist.entries)
--         ]
--
