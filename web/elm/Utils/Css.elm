module Utils.Css exposing (..)

import String

url : String -> String
url path =
  String.concat ["url(\"", path, "\")"]
