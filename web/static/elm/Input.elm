module Input where

type alias Model =
  { originalValue : String
  , value : String
  , validator : (String -> Bool)
  }

type alias Context =
  { address : Signal.Address Action
  , cancelAddress : Signal.Address ()
  , submitAddress : Signal.Address String
  }

type Action
  = NoOp
  | Update String
  | Cancel Context
  | Submit Context

