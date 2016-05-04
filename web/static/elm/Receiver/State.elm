module Receiver.State (initialState, update) where

import Effects exposing (Effects, Never)

import Root exposing (ReceiverState)
import Receiver
import Receiver.Effects

initialState : ReceiverState -> Receiver.Model
initialState state =
  { id = state.id
  , name = state.name
  , online = state.online
  , volume = state.volume
  , zoneId = state.zoneId
  , editingName = False
  }


update : Receiver.Action -> Receiver.Model -> ( Receiver.Model, Effects Receiver.Action )
update action model =
  case action of
    Receiver.Volume maybeVolume ->
      case maybeVolume of
        Just volume ->
          let
              updated = { model | volume = volume }
          in
              ( updated, Receiver.Effects.volume updated )
        Nothing ->
          ( model, Effects.none )

    Receiver.Attach channelId ->
      ( model, (Receiver.Effects.attach channelId model.id) )

    Receiver.Online channelId ->
      ( { model | online = True, zoneId = channelId }, Effects.none )

    Receiver.Offline ->
      ( { model | online = False }, Effects.none )

    _ ->
      ( model, Effects.none )


