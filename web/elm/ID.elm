module ID exposing (..)

-- an alias to allow for referencing any record with an id
type alias T a =
    { a | id : ID }


type alias ID =
    String


type alias Channel =
    ID


type alias Receiver =
    ID


type alias Rendition =
    ID
