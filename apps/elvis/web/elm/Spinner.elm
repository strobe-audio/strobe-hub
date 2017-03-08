module Spinner exposing (..)

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Msg exposing (Msg)


ripple : Svg Msg
ripple =
    svg
        [ width "144px"
        , height "144px"
        , viewBox "0 0 100 100"
        , preserveAspectRatio "xMidYMid"
        , class "uil-ripple"
        ]
        [ rect
            [ x "0"
            , y "0"
            , width "100"
            , height "100"
            , fill "none"
            , class "bk"
            ]
            []
        , g []
            [ animate
                [ attributeName "opacity"
                , dur "2s"
                , repeatCount "indefinite"
                , begin "0s"
                , keyTimes "0;0.33;1"
                , values "1;1;0"
                ]
                []
            , circle
                [ cx "50"
                , cy "50"
                , r "40"
                , stroke "#cec9c9"
                , fill "none"
                , strokeWidth "6"
                , strokeLinecap "round"
                ]
                [ animate
                    [ attributeName "r"
                    , dur "2s"
                    , repeatCount "indefinite"
                    , begin "0s"
                    , keyTimes "0;0.33;1"
                    , values "0;22;44"
                    ]
                    []
                ]
            ]
        , g []
            [ animate
                [ attributeName "opacity"
                , dur "2s"
                , repeatCount "indefinite"
                , begin "1s"
                , keyTimes "0;0.33;1"
                , values "1;1;0"
                ]
                []
            , circle
                [ cx "50"
                , cy "50"
                , r "40"
                , stroke "#3c302e"
                , fill "none"
                , strokeWidth "6"
                , strokeLinecap "round"
                ]
                [ animate
                    [ attributeName "r"
                    , dur "2s"
                    , repeatCount "indefinite"
                    , begin "1s"
                    , keyTimes "0;0.33;1"
                    , values "0;22;44"
                    ]
                    []
                ]
            ]
        ]
