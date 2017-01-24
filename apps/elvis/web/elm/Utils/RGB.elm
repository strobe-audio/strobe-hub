module Utils.RGB exposing (..)

import Array


type alias RGBA =
    { r : Int
    , g : Int
    , b : Int
    , a : Float
    }


cssRGBA : RGBA -> String
cssRGBA color =
    let
        rgba =
            List.append
                (List.map toString [ color.r, color.g, color.b ])
                [ (toString color.a) ]
    in
        "rgba(" ++ (String.join "," rgba) ++ ")"
