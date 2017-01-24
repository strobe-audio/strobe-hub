module Utils.Text exposing (..)

import String


truncateEllipsis : String -> Int -> String
truncateEllipsis text length =
    truncate text length "…"


truncate : String -> Int -> String -> String
truncate text length ellipsis =
    let
        truncated =
            if (String.length text) > length then
                truncateText text length ellipsis
            else
                text
    in
        truncated


truncateText : String -> Int -> String -> String
truncateText text length ellipsis =
    let
        l =
            String.length ellipsis

        truncated =
            String.dropRight ((String.length text) - length + l) text
    in
        String.join "" [ truncated, ellipsis ]
