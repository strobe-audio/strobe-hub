module Receivers.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Receivers
import Receivers.State
import Channel
import Receiver.View


receivers : Signal.Address Receivers.Action -> Receivers.Model -> Channel.Model -> Html
receivers address model channel =
  let
    receivers =
      case model.showAttach of
        True ->
          model.receivers

        False ->
          Receivers.State.attachedReceivers model channel

    count =
      toString
        (List.length
          (Receivers.State.attachedReceivers model channel)
        )

    detached =
      Receivers.State.detachedReceivers model channel

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
          ((div [ class "receivers--title" ] [ text (count ++ " Receivers") ]) :: addButton)
      , div [ class "receivers--list" ] receiverList
      ]
