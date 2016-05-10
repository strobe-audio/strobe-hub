module Receivers (..) where

import Receiver
import ID


type alias Model =
  { receivers : List Receiver.Model
  , showAttach : Bool
  }


type Action
  = NoOp
  | VolumeChanged ( ID.Receiver, Float )
  | Status String ID.Receiver ID.Channel
  | ShowAttach Bool
  | Receiver ID.Receiver Receiver.Action
