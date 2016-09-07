module Volume.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode exposing ((:=))
import Volume


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
                (Json.Decode.object3 handler
                    ("buttons" := Json.Decode.int)
                    ("offsetX" := Json.Decode.int)
                    (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
                )

        mousedown =
            onWithOptions "mousedown"
                options
                (Json.Decode.object2 (\x w -> handler 1 x w)
                    ("offsetX" := Json.Decode.int)
                    (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
                )

        touchstart =
            onWithOptions "touchstart"
                { options | preventDefault = False }
                (Json.Decode.object2 (\x w -> handler 1 (Debug.log "start" x) w)
                    ("offsetX" := Json.Decode.int)
                    (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
                )

        touchend =
            onWithOptions "touchend"
                { options | preventDefault = False }
                (Json.Decode.object2 (\x w -> handler 1 (Debug.log "end" x) w)
                    ("offsetX" := Json.Decode.int)
                    (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
                )

        touchmove =
            onWithOptions "touchmove"
                { options | preventDefault = False }
                (Json.Decode.object2 (\x w -> handler 1 (Debug.log "move" x) w)
                    ("offsetX" := Json.Decode.int)
                    (Json.Decode.at [ "target", "offsetWidth" ] Json.Decode.int)
                )
    in
        div [ class "volume-control" ]
            [ div [ class "volume-mute-btn fa fa-volume-off", onClick (Volume.Change (Just 0.0)) ] []
            , div [ class "volume", mousemove, touchmove, mousedown, touchstart, touchend ]
                [ div [ class "volume-level", style [ ( "width", (toString (volume * 100)) ++ "%" ) ] ] []
                , div [ class "volume-label" ] [ label ]
                ]
            , div [ class "volume-full-btn fa fa-volume-up", onClick (Volume.Change (Just 1.0)) ] []
            ]
