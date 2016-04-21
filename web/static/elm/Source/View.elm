module Source.View where

import String
import Root

duration : Root.Source -> String
duration source =
  case source.metadata.duration_ms of
    Nothing ->
      ""
    Just duration ->
      let
          totalSeconds = (duration // 1000)
          hours = (totalSeconds // 3600) % 24
          minutes = (totalSeconds // 60) % 60
          seconds = totalSeconds % 60
          values = List.map (String.padLeft 2 '0') (List.map toString [hours, minutes, seconds])

      in
          List.foldr (++) "" (List.intersperse ":" values)
