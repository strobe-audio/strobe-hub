module Receivers.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html
import Debug


--

import Channel
import Receiver
import Receiver.View
import Root
import Msg exposing (Msg)
import Utils.Touch exposing (onSingleTouch)


receivers : Root.Model -> Channel.Model -> Html Msg
receivers model channel =
    let
        attached =
            Receiver.attachedReceivers model.receivers channel

        receivers =
            case model.showAttachReceiver of
                True ->
                    model.receivers

                False ->
                    attached

        count =
            toString (List.length attached)

        detached =
            Receiver.detachedReceivers model.receivers channel

        online =
            (Receiver.onlineReceivers model.receivers)

        receiverEntry receiver =
            case receiver.channelId == channel.id of
                True ->
                    Html.map (Msg.Receiver receiver.id) (Receiver.View.attached receiver channel)

                False ->
                    Html.map (Msg.Receiver receiver.id) (Receiver.View.detached receiver channel)

        receiverList =
            List.map receiverEntry receivers

        ( action, addButton ) =
            case List.length detached of
                0 ->
                    ( Msg.NoOp, [] )

                _ ->
                    case (List.length online) of
                        0 ->
                            ( Msg.NoOp, [] )

                        _ ->
                            if model.showAttachReceiver then
                                ( (Msg.ShowAttachReceiver False)
                                , [ div [ class "receivers--add" ] [ i [ class "fa fa-caret-up" ] [] ] ]
                                )
                            else
                                ( (Msg.ShowAttachReceiver True)
                                , [ div [ class "receivers--add" ] [ i [ class "fa fa-plus" ] [] ] ]
                                )
    in
        div [ class "receivers" ]
            [ div [ class "receivers--head", onClick action, onSingleTouch action ]
                ((div [ class "receivers--title" ] [ text (count ++ "/" ++ (toString (List.length model.receivers)) ++ " Receivers") ]) :: addButton)
            , div [ class "receivers--list" ] receiverList
            ]
