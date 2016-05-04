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
  , channelId = state.channelId
  , editingName = False
  }


update : Receiver.Action -> Receiver.Model -> ( Receiver.Model, Effects Receiver.Action )
update action model =
  case action of
    Receiver.Volume maybeVolume ->
      case maybeVolume of
        Just volume ->
          let
            updated =
              { model | volume = volume }
          in
            ( updated, Receiver.Effects.volume updated )

        Nothing ->
          ( model, Effects.none )

    -- The volume has been changed by someone else
    Receiver.VolumeChanged volume ->
      ( { model | volume = volume }, Effects.none )

    Receiver.Attach channelId ->
      ( model, (Receiver.Effects.attach channelId model.id) )

    Receiver.Online channelId ->
      ( { model | online = True, channelId = channelId }, Effects.none )

    Receiver.Offline ->
      ( { model | online = False }, Effects.none )

    _ ->
      ( model, Effects.none )
