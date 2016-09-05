module Receivers.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Receivers
import Receivers.State
import Channel
import Receiver.View
import Debug


receivers : Signal.Address Receivers.Action -> Receivers.Model -> Channel.Model -> Html
receivers address model channel =
  let
    attached = Receivers.attachedReceivers model channel

    receivers =
      case model.showAttach of
        True ->
          model.receivers

        False ->
          attached

    count =
      toString
        (List.length attached)

    detached =
      Receivers.detachedReceivers model channel

    online =
      (Receivers.onlineReceivers model)

    receiverEntry receiver =
      let
        receiverAddress =
          Signal.forwardTo address (Receivers.Receiver receiver.id)
      in
        case receiver.channelId == channel.id of
          True ->
            Receiver.View.attached receiverAddress receiver channel

          False ->
            Receiver.View.detached receiverAddress receiver channel

    receiverList =
      List.map receiverEntry receivers

    ( action, addButton ) =
      case List.length detached of
        0 ->
          ( Receivers.NoOp, [] )

        _ ->
          case  (List.length online) of
            0 ->
              ( Receivers.NoOp, [] )

            _ ->
              if model.showAttach then
                ( (Receivers.ShowAttach False)
                , [ div [ class "receivers--add" ] [ i [ class "fa fa-caret-up" ] [] ] ]
                )
              else
                ( (Receivers.ShowAttach True)
                , [ div [ class "receivers--add" ] [ i [ class "fa fa-plus" ] [] ] ]
                )
  in
    div
      [ class "receivers" ]
      [ div
          [ class "receivers--head", onClick address action ]
          ((div [ class "receivers--title" ] [ text (count ++ "/" ++ (toString (List.length model.receivers)) ++ " Receivers") ]) :: addButton)
      , div [ class "receivers--list" ] receiverList
      ]
