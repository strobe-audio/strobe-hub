module Receivers.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.App exposing (map)
import Receivers
-- import Receivers.State
import Channel
import Receiver.View
import Debug
import Root
import Msg exposing (Msg)


receivers : Root.Model -> Channel.Model -> Html Msg
receivers model channel =
    let
        attached =
            Receivers.attachedReceivers model.receivers channel

        receivers =
            case model.showAttachReceiver of
                True ->
                    model.receivers

                False ->
                    attached

        count =
            toString (List.length attached)

        detached =
            Receivers.detachedReceivers model.receivers channel

        online =
            (Receivers.onlineReceivers model.receivers)

        receiverEntry receiver =
            case receiver.channelId == channel.id of
                True ->
                    map (Msg.Receiver receiver.id) (Receiver.View.attached receiver channel)

                False ->
                    map (Msg.Receiver receiver.id) (Receiver.View.detached receiver channel)

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
            [ div [ class "receivers--head", onClick action ]
                ((div [ class "receivers--title" ] [ text (count ++ "/" ++ (toString (List.length model.receivers)) ++ " Receivers") ]) :: addButton)
            , div [ class "receivers--list" ] receiverList
            ]
