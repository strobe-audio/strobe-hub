module Receiver.View where


import Html exposing (..)
import Html.Attributes exposing (..)

import Root
import Receiver
import Volume.View

attached : Signal.Address Receiver.Action -> Receiver.Model -> Html
attached address receiver =
  let
      volumeAddress = (Signal.forwardTo address Receiver.Volume)
  in
      div
        [ classList
          [ ("receiver", True)
          , ("receiver--online", receiver.online)
          , ("receiver--offline", not receiver.online)
          ]
        ]
        [ Volume.View.control volumeAddress receiver.volume receiver.name ]
