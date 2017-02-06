module Source.View exposing (..)

import String
import Rendition
import List.Extra


duration : Rendition.Source -> String
duration source =
    durationString source.duration_ms


timeRemaining : Rendition.Source -> Int -> String
timeRemaining source position =
    case source.duration_ms of
        Nothing ->
            ""

        Just duration ->
            let
                remaining =
                    duration - position
            in
                "−" ++ (durationString (Just remaining))


durationString : Maybe Int -> String
durationString durationMs =
    case durationMs of
        Nothing ->
            "∞"

        Just duration ->
            let
                totalSeconds =
                    (duration // 1000)

                hours =
                    (totalSeconds // 3600) % 24

                minutes =
                    (totalSeconds // 60) % 60

                seconds =
                    totalSeconds % 60

                times =
                    case hours of
                        0 ->
                            [ minutes, seconds ]

                        _ ->
                            [ hours, minutes, seconds ]

                values =
                    List.map (String.padLeft 2 '0') (List.map toString times)
            in
                List.foldr (++) "" (List.intersperse ":" values)
