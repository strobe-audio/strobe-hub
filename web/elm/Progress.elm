module Progress exposing (..)

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Html
import Html.Attributes as Attr
import VirtualDom exposing (attribute)
import Msg exposing (Msg)
import Utils.RGB exposing (RGBA)


circular : Int -> RGBA -> Bool -> Float -> Svg Msg
circular size rgba playing percent =
    let

        dim = size - 1
        rad = (toFloat size) / 2

        sw = 3.5

        -- percent = 65.0

        radius =
           rad - (sw / 2.0) - 1.0
            -- ((toFloat dim) / 2) - 4

        r_ =
            (toString radius)

        alpha = (angle percent)

        circumference =
            2.0 * radius * pi

        viewBox_ = String.join " "
          [ (toString -rad)
          , (toString -rad)
          , (toString size)
          , (toString size)
          ]
        largeArcFlag = if percent > 50 then
          "1"
          else
            "0"

        clockwiseFlag = "1"

        targetX = if percent == 100 then
          -0.00001
          else
            (sin alpha) * radius

        targetY = (cos (alpha - pi)) * radius

        path_ = String.join " "
          [ "M0," ++ (toString (-radius))
          , "A" ++ r_ ++ "," ++ r_
          , "0"
          , largeArcFlag ++ "," ++ clockwiseFlag
          , (toString targetX) ++ "," ++ (toString targetY)
          ]

        strokeColor =
            case playing of
                True ->
                    (Utils.RGB.cssRGBA rgba)

                False ->
                    "rgba(255, 255, 255, 0.5)"
    in
        Html.div [ Attr.class "progress-circular" ]
            [ svg
                [ version "1.1"
                , width (toString size)
                , height (toString size)
                , viewBox viewBox_
                , class "progress-circular--root"
                ]
                [ circle
                    [ class "progress-circular--background", stroke "rgba(255, 255, 255, 0.2)", strokeWidth "2", r (toString (radius + (sw/2) - 1.5)), cx "0", cy "0", fill "none", transform "rotate(-90deg)"]
                    []
                , Svg.path
                    [ class "progress-circular--arc", fill "none", d path_, stroke strokeColor, strokeWidth (toString sw) ]
                    []
                ]
            ]

getArcLength : Float -> Float -> Float
getArcLength radius percent =
  0.02 * pi * radius * percent

-- percent as an angle
angle : Float -> Float
angle percent =
  0.02 * pi * percent
