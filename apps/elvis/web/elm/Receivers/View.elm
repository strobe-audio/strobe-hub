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



attached : Root.Model -> Channel.Model -> Html Msg
attached model channel =
    let
        receivers =
            Receiver.attachedReceivers channel model.receivers

        active =
            (List.length receivers) > 0

        receiverEntry receiver =
            Html.map (Msg.Receiver receiver.id) (Receiver.View.attached receiver channel)

        contents =
            if active then
                div [ class "receivers--list" ] (List.map receiverEntry receivers)
            else
                div [ class "receivers--active-empty" ] [ text "Add receivers from list below" ]
    in
        div [ class "receivers--list" ] (List.map receiverEntry receivers)


detached : Root.Model -> Channel.Model -> Html Msg
detached model channel =
    let
        receivers =
            Receiver.detachedReceivers channel model.receivers

        active =
            (List.length receivers) > 0

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
