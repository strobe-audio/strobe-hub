module Encoding exposing (uriEncode)

import Native.Encoding


uriEncode : String -> String
uriEncode =
    Native.Encoding.uriEncode
