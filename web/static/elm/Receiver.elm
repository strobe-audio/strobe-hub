module Receiver (..) where

import ID


type alias Model =
  { id : ID.Receiver
  , name : String
  , online : Bool
  , volume : Float
  , channelId : ID.Channel
  , editingName : Bool
  }


type Action
  = NoOp
  | Volume (Maybe Float)
  | VolumeChanged Float
  | Attach ID.Channel
  | Online ID.Channel
  | Offline


sort : List Model -> List Model
sort receivers =
  List.sortBy (\r -> r.name) receivers
