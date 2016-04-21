module Receiver.State (initialState) where

import Types exposing (ReceiverState)
import Receiver.Types exposing (Receiver)

initialState : ReceiverState -> Receiver
initialState state =
  { id = state.id
  , name = state.name
  , online = state.online
  , volume = state.volume
  , zoneId = state.zoneId
  , editingName = False
  }


