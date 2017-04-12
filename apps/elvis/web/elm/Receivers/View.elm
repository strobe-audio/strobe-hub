module Receivers.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html
import Html.Keyed
import Debug


--

import Channel
import Receiver
import Receiver.View
import Root
import Msg exposing (Msg)
import Utils.Touch exposing (onSingleTouch)


control : Root.Model -> Html Msg
control model =
    let
        receivers =
            Receiver.sortByActive model.receivers

        receiverEntry receiver =
            Html.map (Msg.Receiver receiver.id) (Receiver.View.attached receiver)
    in
        div [] (List.map receiverEntry receivers)


attached : Root.Model -> Channel.Model -> Html Msg
attached model channel =
    let
        receivers =
            Receiver.attachedReceivers channel model.receivers
                |> Receiver.sortByActive

        receiverEntry receiver =
            Html.map (Msg.Receiver receiver.id) (Receiver.View.attached receiver)
    in
        div [ class "receivers--list" ] (List.map receiverEntry receivers)


detached : Root.Model -> Channel.Model -> Html Msg
detached model channel =
    let
        receivers =
            Receiver.detachedReceivers channel model.receivers
                |> Receiver.sortByActive

        receiverEntry receiver =
            Html.map
                (Msg.Receiver receiver.id)
                -- use keyed nodes so that active state doesn't stay with div
                -- rather than receiver
                (Html.Keyed.node
                    "div"
                    []
                    [ ( receiver.id, Receiver.View.detached receiver channel ) ]
                )
    in
        div [ class "receivers--list" ] (List.map receiverEntry receivers)
