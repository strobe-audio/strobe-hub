module Receiver.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Root
import Receiver
import Channel
import Volume.View


attached : Signal.Address Receiver.Action -> Receiver.Model -> Html
attached address receiver =
  let
    volumeAddress =
      (Signal.forwardTo address Receiver.Volume)
  in
    div
      [ classList
          [ ( "receiver", True )
          , ( "receiver--online", receiver.online )
          , ( "receiver--offline", not receiver.online )
          ]
      ]
      [ Volume.View.control volumeAddress receiver.volume receiver.name ]


attach : Signal.Address Receiver.Action -> Channel.Model -> Receiver.Model -> Html
attach address channel receiver =
  div
    [ class "channel-receivers--available-receiver" ]
    [ div
        [ class "channel-receivers--add-receiver"
        , onClick address (Receiver.Attach channel.id)
        ]
        [ text receiver.name ]
    , div
        [ class "channel-receivers--edit-receiver" ]
        [ i [ class "fa fa-pencil" ] [] ]
    ]
