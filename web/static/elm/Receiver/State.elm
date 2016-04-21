module Receiver.State (initialState) where

import Types exposing (ReceiverState)
import Receiver

initialState : ReceiverState -> Receiver.Model
initialState state =
  { id = state.id
  , name = state.name
  , online = state.online
  , volume = state.volume
  , zoneId = state.zoneId
  , editingName = False
  }


