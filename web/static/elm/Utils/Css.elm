module Utils.Css (..) where

import String

url : String -> String
url path =
  String.concat ["url(\"", path, "\")"]
