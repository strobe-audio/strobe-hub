module Receivers.State exposing (..)

import Root
import Receivers
import Receiver
import Receiver.State
import Channel
import ID


initialState : Receivers.Model
initialState =
  { receivers = []
  , showAttach = False
  }


loadReceivers : Root.BroadcasterState -> Receivers.Model -> Receivers.Model
loadReceivers state model =
  let
    receivers =
      List.map Receiver.State.initialState state.receivers
  in
    { model | receivers = receivers }


update : Receivers.Msg -> Receivers.Model -> ( Receivers.Model, Cmd Receivers.Msg )
update action model =
  case action of
    Receivers.ShowAttach show ->
      ( { model | showAttach = show }, Cmd.none )

    Receivers.Receiver receiverId receiverAction ->
      let
        updateReceiver receiver =
          if receiver.id == receiverId then
            let
              ( receiver', effect ) =
                (Receiver.State.update receiverAction receiver)
            in
              ( receiver', Cmd.map (Receivers.Receiver receiverId) effect )
          else
            ( receiver, Cmd.none )

        ( receivers, effects ) =
          (List.map updateReceiver model.receivers) |> List.unzip
      in
        ( { model | receivers = receivers }, Cmd.batch effects )

    Receivers.Status status receiverId channelId ->
      case status of
        "receiver_added" ->
          let
            ( model', effect ) =
              update (Receivers.Receiver receiverId (Receiver.Online channelId)) model

            allAttachedToChannel =
              List.isEmpty (Receivers.detachedReceivers model' { id = channelId })

            updatedModel =
              if allAttachedToChannel then
                { model' | showAttach = False }
              else
                model'
          in
            ( updatedModel, effect )

        "receiver_removed" ->
          let
            ( model', effect ) =
              update (Receivers.Receiver receiverId Receiver.Offline) model
          in
            ( model', effect )

        "reattach_receiver" ->
          let
            ( model', effect ) =
              update (Receivers.Receiver receiverId (Receiver.Attached channelId)) model
          in
            ( model', effect )

        _ ->
          ( model, Cmd.none )

    Receivers.VolumeChanged ( receiverId, volume ) ->
      update (Receivers.Receiver receiverId (Receiver.VolumeChanged volume)) model

    _ ->
      ( model, Cmd.none )


