module Input.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import Input


inputSubmitCancel : Input.Model -> Html Input.Msg
inputSubmitCancel model =
    let
        valid =
            model.validator model.value
    in
        div [ class "input" ]
            [ input
                [ class "input--input"
                , type' "text"
                , placeholder "Channel name..."
                , value model.value
                , onInput Input.Update
                , onKeyDown Input.Submit Input.Cancel
                , autofocus True
                , attribute "autocapitalize" model.autoCapitalize
                ]
                []
            , div
                [ classList [ ( "input--submit", True ), ( "input--submit__valid", valid ) ]
                , onClick Input.Submit
                ]
                []
            , div [ class "input--cancel", onClick Input.Cancel ] []
            ]


onKeyDown : Input.Msg -> Input.Msg -> Attribute Input.Msg
onKeyDown submitMsg cancelMsg =
    on "keydown"
        (Json.customDecoder keyCode (submitOrCancel submitMsg cancelMsg))


submitOrCancel : Input.Msg -> Input.Msg -> Int -> Result String Input.Msg
submitOrCancel submitMsg cancelMsg code =
    case code of
        13 ->
            Ok submitMsg

        27 ->
            Ok cancelMsg

        _ ->
            Err "ignored key code"
