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


attached : Root.Model -> Channel.Model -> Html Msg
attached model channel =
    let
        receivers =
            Receiver.attachedReceivers model.receivers channel

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
        -- div
        --     [ class "receivers" ]
        --     [ div
        --         [ class "receivers--head" ]
        --         [ div
        --             [ class "receivers--title" ]
        --             [ (text ((toString (List.length receivers)) ++ " Attached Receivers"))
        --             ]
        --         ]
        --     , contents
        --     ]


detached : Root.Model -> Channel.Model -> Html Msg
detached model channel =
    let
        receivers =
            Receiver.detachedReceivers model.receivers channel

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
        -- if active then
        --     div
        --         [ class "receivers" ]
        --         [ div
        --             [ class "receivers--head" ]
        --             [ div
        --                 [ class "receivers--title" ]
        --                 [ (text ((toString (List.length receivers)) ++ " Detached Receivers"))
        --                 ]
        --             ]
        --         , div [ class "receivers--list" ] (List.map receiverEntry receivers)
        --         ]
        -- else
        --     div [] []
        div [ class "receivers--list" ] (List.map receiverEntry receivers)
