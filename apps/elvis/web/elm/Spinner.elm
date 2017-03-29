module Spinner exposing (..)

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Msg exposing (Msg)
import Random
import List.Extra


ripple : Int -> Svg Msg
ripple time =
    let
        color =
            "#FF2D00"

        strokeWidth_ =
            "0.9px"

        seed =
            Random.initialSeed time

        delays =
            [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ]

        ringCount =
            List.length delays

        randDuration =
            Random.int 2 9

        randParams =
            Random.list ringCount randDuration

        ( durations, _ ) =
            Random.step randParams seed

        params =
            durations
                |> List.Extra.zip delays

        rings =
            List.map ring params

        ring : ( Int, Int ) -> Svg Msg
        ring ( delay, duration ) =
            let
                dur_ =
                    (toString duration) ++ "s"

                begin_ =
                    (toString delay) ++ "s"
            in
                g []
                    [ animate
                        [ attributeName "opacity"
                        , dur dur_
                        , repeatCount "indefinite"
                        , begin begin_
                        , keyTimes "0;0.33;1"
                        , values "1;1;0"
                        ]
                        []
                    , circle
                        [ cx "50"
                        , cy "50"
                        , r "0"
                        , stroke color
                        , fill "none"
                        , strokeWidth strokeWidth_
                        , strokeLinecap "round"
                        ]
                        [ animate
                            [ attributeName "r"
                            , dur dur_
                            , repeatCount "indefinite"
                            , begin begin_
                            , keyTimes "0;0.33;1"
                            , values "0;22;44"
                            ]
                            []
                        ]
                    ]

        rect_ =
            rect
                [ x "0"
                , y "0"
                , width "100"
                , height "100"
                , fill "none"
                , class "bk"
                ]
                []
    in
        svg
            [ viewBox "0 0 100 100"
            , preserveAspectRatio "xMidYMid"
            , class "uil-ripple"
            ]
            (rect_ :: rings)
