module Receiver.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html
import Json.Decode as Json
import Msg exposing (Msg)


--

import Root
import Receiver
import Channel
import Volume.View
import Input.View
import Utils.Touch


receiverClasses : Receiver.Model -> Bool -> List ( String, Bool )
receiverClasses receiver attached =
    [ ( "receiver", True )
    , ( "receiver__online", receiver.online )
    , ( "receiver__offline", not receiver.online )
    , ( "receiver__attached", attached )
    , ( "receiver__detached", not attached )
    ]


attached : Receiver.Model -> Channel.Model -> Html Receiver.Msg
attached receiver channel =
    let
        onClickEdit =
            onWithOptions "click"
                { defaultOptions | stopPropagation = True }
                (Json.succeed (Receiver.ShowEditName True))

        editNameInput =
            case receiver.editName of
                False ->
                    div [] []

                True ->
                    Input.View.inputSubmitCancel receiver.editNameInput

        receiverLabel receiver =
            div [ class "receiver--name" ] [ text receiver.name ]
    in
        div [ id ("receiver-" ++ receiver.id), classList (receiverClasses receiver True) ]
            [ div [ class "receiver--view" ]
                [ div [ class "receiver--state" ] []
                , div [ class "receiver--volume" ]
                    [ Html.map Receiver.Volume (Volume.View.control receiver.volume (receiverLabel receiver))
                    ]
                , div [ class "receiver--action" ]
                    [ div
                        [ class "receiver--action__edit"
                        , onClickEdit
                        , mapTouch (Utils.Touch.touchStart (Receiver.ShowEditName True))
                        , mapTouch (Utils.Touch.touchEnd (Receiver.ShowEditName True))
                        ]
                        []
                    ]
                ]
            , div
                [ classList
                    [ ( "receiver--edit", True )
                    , ( "receiver--edit__active", receiver.editName )
                    ]
                ]
                [ Html.map Receiver.EditName editNameInput ]
            ]


detached : Receiver.Model -> Channel.Model -> Html Receiver.Msg
detached receiver channel =
    let
        msg =
            (Receiver.Attach channel.id)
    in
        div
            [ classList (receiverClasses receiver False)
            , onClick msg
            , mapTouch (Utils.Touch.touchStart msg)
            , mapTouch (Utils.Touch.touchEnd msg)
            ]
            [ div [ class "receiver--state receiver--state__detached" ] []
            , div [ class "receiver--name" ] [ text receiver.name ]
            , div [ class "receiver--action" ] []
            ]


attach : Channel.Model -> Receiver.Model -> Html Receiver.Msg
attach channel receiver =
    div [ class "channel-receivers--available-receiver" ]
        [ div
            [ class "channel-receivers--add-receiver"
            , onClick (Receiver.Attach channel.id)
            ]
            [ text receiver.name ]
        , div [ class "channel-receivers--edit-receiver" ]
            [ i [ class "fa fa-pencil" ] [] ]
        ]


mapTouch : Attribute (Utils.Touch.E Receiver.Msg) -> Attribute Receiver.Msg
mapTouch a =
    Html.Attributes.map Receiver.SingleTouch a
