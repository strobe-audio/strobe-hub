module State (initialState, update, activeChannel) where

import Effects exposing (Effects, Never)
import Debug
import List.Extra

import Types exposing (..)
import Channel
import Channel.State


initialState : Model
initialState =
  let
    model =
      { channels = []
      , choosingZone = False
      , activeChannelId = Nothing
      }
      -- , library = Library.init
      -- , ui = initUIState [] []
      -- , activeState = "channel"
      -- }
  in
    model

broadcasterState : BroadcasterState -> List Channel.Model
broadcasterState state =
  List.map (Channel.State.initialState (Debug.log "state" state)) state.channels


activeChannel : Model -> Maybe Channel.Model
activeChannel model =
  case model.activeChannelId of
    Nothing ->
      Nothing
    Just id ->
      List.Extra.find (\c -> c.id == id) model.channels


update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      (model, Effects.none)

    InitialState state ->
      let
          channels = (broadcasterState state)
          activeChannelId = Maybe.map (\channel -> channel.id) (List.head channels)
          updatedModel =
            { model
            | channels = channels
            , activeChannelId = activeChannelId
            }
      in
        ( updatedModel, Effects.none )


    ModifyChannel channelId channelAction ->
      let
          updateChannel channel =
            if channel.id == channelId then
              let
                  (updatedChannel, effect) = (Channel.State.update channelAction channel)
              in
                  (updatedChannel, Effects.map (ModifyChannel channelId) effect)
            else
              ( channel, Effects.none )
          (channels, effects) = (List.map updateChannel model.channels) |> List.unzip
      in
        ({ model | channels = channels }, (Effects.batch effects))

    SetMode mode ->
      (model, Effects.none)

    ChooseChannel activeChannel ->
      (model, Effects.none)


