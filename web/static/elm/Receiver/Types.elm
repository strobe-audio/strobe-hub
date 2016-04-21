module Receiver.Types where


type alias Receiver =
  { id :       String
  , name :     String
  , online :   Bool
  , volume :   Float
  , zoneId :   String
  , editingName : Bool
  }

type Action
  = NoOp
  | Volume Float
  | Attach String
