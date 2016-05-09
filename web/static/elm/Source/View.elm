module Source.View (..) where

import String
import Root
import List.Extra


duration : Root.Source -> String
duration source =
  durationString source.metadata.duration_ms


timeRemaining : Root.Source -> Int -> String
timeRemaining source position =
  case source.metadata.duration_ms of
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
      ""

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
