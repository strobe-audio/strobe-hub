module Volume.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode exposing (field)
import Volume
import Touch
import Utils.Touch exposing (onUnifiedClick, onSingleTouch)


control : Float -> Html Volume.Msg -> Html Volume.Msg
control volume label =
    let
        handler buttons offset width =
            let
                maybeVolume =
                    case buttons of
                        1 ->
                            Just ((toFloat offset) / (toFloat width))

                        _ ->
                            Nothing
            in
                (Volume.Change maybeVolume)

        options =
            { stopPropagation = False, preventDefault = False }

        mousemove =
            onWithOptions "mousemove"
                options
                (Json.Decode.map3 handler
                    (field "buttons" Json.Decode.int)
                    (field "offsetX" Json.Decode.int)
                    (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
                )

        mousedown =
            onWithOptions "mousedown"
                options
                (Json.Decode.map2 (\x w -> handler 1 x w)
                    (field "offsetX" Json.Decode.int)
                    (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
                )

        decodeTouch label =
            (Json.Decode.map3 (\px ol w -> handler 1 (px - ol) w)
                (field "pageX" Json.Decode.int)
                (Json.Decode.at [ "target", "offsetLeft" ] Json.Decode.int)
                (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
            )

        touchstart =
            onWithOptions "touchstart"
                Touch.preventAndStop
                (decodeTouch "touch start")

        touchmove =
            onWithOptions "touchmove"
                Touch.preventAndStop
                (decodeTouch "touch move")
    in
        div [ class "volume-control" ]
            [ div ([ class "volume-mute-btn fa fa-volume-off" ] ++ (onUnifiedClick (Volume.Change (Just 0.0)))) []
            , div [ class "volume", touchstart, touchmove, mousedown, mousemove ]
                [ div [ class "volume-level", style [ ( "width", (toString (volume * 100)) ++ "%" ) ] ] []
                , div [ class "volume-label" ] [ label ]
                ]
            , div ([ class "volume-full-btn fa fa-volume-up" ] ++ (onUnifiedClick (Volume.Change (Just 1.0)))) []
            ]
