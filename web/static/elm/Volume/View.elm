module Volume.View where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import Json.Decode exposing ((:=))

control : Signal.Address (Maybe Float) -> Float -> String -> Html
control address volume label  =
  let
      handler buttons offset width =
        let
            maybeVolume =
              case buttons of
                1 ->
                  Just ( (toFloat offset) / (toFloat width) )
                _ ->
                  Nothing
        in
            (Signal.message address maybeVolume)

      options = { stopPropagation = False, preventDefault = False }

      mousemove = onWithOptions
        "mousemove"
        options
        (Json.Decode.object3 (,,)
          ("buttons" := Json.Decode.int)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(m, x, w) -> handler m x w)

      mousedown = onWithOptions
        "mousedown"
        options
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) -> handler 1 x w)

      touchstart = onWithOptions
        "touchstart"
        { options | preventDefault = False }
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) -> handler 1 (Debug.log "start" x) w)

      touchend = onWithOptions
        "touchend"
        { options | preventDefault = False }
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) -> handler 1 (Debug.log "end" x) w)

      touchmove = onWithOptions
        "touchmove"
        { options | preventDefault = False }
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) ->  handler 1 (Debug.log "move" x) w)
  in
      div [ class "volume-control" ]
          [ div [ class "volume-mute-btn fa fa-volume-off", onClick address (Just 0.0) ] []
          , div [ class "volume",  mousemove, touchmove, mousedown, touchstart, touchend]
              [ div [ class "volume-level", style [("width", (toString (volume * 100)) ++ "%")] ] []
              , div [ class "volume-label" ] [ text label ]
              ]
          , div [ class "volume-full-btn fa fa-volume-up", onClick address (Just 1.0) ] []
          ]

