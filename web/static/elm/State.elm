module State (initialState, update, activeChannel) where

import Effects exposing (Effects, Never)
import Debug
import List.Extra

import Types -- exposing (..)
import Channel
import Channel.State
import Receiver.State


initialState : Types.Model
initialState =
  let
    model =
      { channels = []
      , receivers = []
      , choosingZone = False
      , activeChannelId = Nothing
      }
      -- , library = Library.init
      -- , ui = initUIState [] []
      -- , activeState = "channel"
      -- }
  in
    model

broadcasterState : Types.BroadcasterState -> List Channel.Model
broadcasterState state =
  List.map (Channel.State.initialState (Debug.log "state" state)) state.channels


activeChannel : Types.Model -> Maybe Channel.Model
activeChannel model =
  case model.activeChannelId of
    Nothing ->
      Nothing
    Just id ->
      List.Extra.find (\c -> c.id == id) model.channels


update : Types.Action -> Types.Model -> (Types.Model, Effects Types.Action)
update action model =
  case action of
    Types.NoOp ->
      (model, Effects.none)

    Types.InitialState state ->
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


    Types.ModifyChannel channelId channelAction ->
      let
          updateChannel channel =
            if channel.id == channelId then
              let
                  (updatedChannel, effect) = (Channel.State.update channelAction channel)
              in
                  (updatedChannel, Effects.map (Types.ModifyChannel channelId) effect)
            else
              ( channel, Effects.none )
          (channels, effects) = (List.map updateChannel model.channels) |> List.unzip
      in
        ({ model | channels = channels }, (Effects.batch effects))

    Types.SetMode mode ->
      (model, Effects.none)

    Types.ChooseChannel activeChannel ->
      (model, Effects.none)


