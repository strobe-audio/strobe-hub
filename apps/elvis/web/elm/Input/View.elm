module Input.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import Input
import Utils.Touch exposing (onSingleTouch)


inputSubmitCancel : Input.Model -> Html Input.Msg
inputSubmitCancel model =
    let
        valid =
            model.validator model.value

        clickSubmit =
            onWithOptions
                "click"
                { defaultOptions | stopPropagation = True }
                (Json.succeed Input.Submit)

        clickCancel =
            onWithOptions
                "click"
                { defaultOptions | stopPropagation = True }
                (Json.succeed Input.Cancel)
    in
        div [ class "input" ]
            [ input
                [ class "input--input"
                , type_ "text"
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
                , clickSubmit
                , onSingleTouch Input.Submit
                ]
                []
            , div [ class "input--cancel", clickCancel, onSingleTouch Input.Cancel ] []
            ]


onKeyDown : Input.Msg -> Input.Msg -> Attribute Input.Msg
onKeyDown submitMsg cancelMsg =
    on "keydown" (Json.andThen (submitOrCancel submitMsg cancelMsg) keyCode)


submitOrCancel : Input.Msg -> Input.Msg -> Int -> Json.Decoder Input.Msg
submitOrCancel submitMsg cancelMsg code =
    case code of
        13 ->
            Json.succeed submitMsg

        27 ->
            Json.succeed cancelMsg

        _ ->
            Json.fail "ignored key code"
