module State (initialState, update, activeChannel, attachedReceivers, detachedReceivers) where

import Effects exposing (Effects, Never)
import Debug
import List.Extra

import Root
import Channel
import Channel.State
import Receiver
import Receiver.State


initialState : Root.Model
initialState =
  let
    model =
      { channels = []
      , receivers = []
      , showChannelSwitcher = False
      , activeChannelId = Nothing
      }
      -- , library = Library.init
      -- , ui = initUIState [] []
      -- , activeState = "channel"
      -- }
  in
    model


broadcasterState : Root.BroadcasterState -> List Channel.Model
broadcasterState state =
  List.map (Channel.State.initialState (Debug.log "state" state)) state.channels


activeChannel : Root.Model -> Maybe Channel.Model
activeChannel model =
  case model.activeChannelId of
    Nothing ->
      Nothing
    Just id ->
      List.Extra.find (\c -> c.id == id) model.channels


update : Root.Action -> Root.Model -> (Root.Model, Effects Root.Action)
update action model =
  case action of
    Root.NoOp ->
      (model, Effects.none)

    Root.InitialState state ->
      let
          channels = List.map (Channel.State.initialState state) state.channels
          receivers = List.map Receiver.State.initialState state.receivers
          activeChannelId = Maybe.map (\channel -> channel.id) (List.head channels)
          updatedModel =
            { model
            | channels = channels
            , receivers = receivers
            , activeChannelId = activeChannelId
            }
      in
        ( updatedModel, Effects.none )


    Root.ModifyChannel channelId channelAction ->
      let
          updateChannel channel =
            if channel.id == channelId then
              let
                  (updatedChannel, effect) = (Channel.State.update channelAction channel)
              in
                  (updatedChannel, Effects.map (Root.ModifyChannel channelId) effect)
            else
              ( channel, Effects.none )

          (channels, effects) = (List.map updateChannel model.channels) |> List.unzip
      in
        ({ model | channels = channels }, (Effects.batch effects))

    Root.ModifyReceiver receiverId receiverAction ->
      let
          updateReceiver receiver =
            if receiver.id == receiverId then
              let
                  (updatedReceiver, effect) = (Receiver.State.update receiverAction receiver)
              in
                  (updatedReceiver, Effects.map (Root.ModifyReceiver receiver.id) effect)
            else
              ( receiver, Effects.none )

          (receivers, effects) = (List.map updateReceiver model.receivers) |> List.unzip
      in
        ({ model | receivers = receivers }, (Effects.batch effects))


    Root.SetMode mode ->
      (model, Effects.none)

    Root.ToggleChannelSelector ->
      ({ model | showChannelSwitcher = not(model.showChannelSwitcher) }, Effects.none)

    Root.ChooseChannel channel ->
      let
          updatedModel =
            { model
            | showChannelSwitcher = False
            , activeChannelId = Just channel.id
            }
      in
          (updatedModel, Effects.none)

    Root.SourceProgress event ->
      ( model, Effects.none )





attachedReceivers : Root.Model -> Channel.Model -> List Receiver.Model
attachedReceivers model channel =
  List.filter (\r -> r.zoneId == channel.id) model.receivers


detachedReceivers : Root.Model -> Channel.Model -> List Receiver.Model
detachedReceivers model channel =
  List.filter (\r -> r.zoneId /= channel.id) model.receivers

