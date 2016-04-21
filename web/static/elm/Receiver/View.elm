module Receiver.View where


import Html exposing (..)
import Html.Attributes exposing (..)

import Receiver.Types exposing (Receiver)

attached : Signal.Address Receiver.Types.Action -> Receiver -> Html
attached address receiver =
  div [
    classList [ ("receiver", True)
    , ("receiver--online", receiver.online)
    , ("receiver--offline", not receiver.online) ]
  ] []
    -- [ Volume.volumeControl address receiver.volume receiver.name (UpdateReceiverVolume receiver) ]
