module Channel where

-- import Types exposing (Action)
import Receiver
import Rendition.Types exposing (Rendition)


type alias Model =
  { id:       String
  , name:     String
  , position: Int
  , volume:   Float
  , playing:   Bool
  , receivers : List Receiver.Model
  , playlist : List Rendition
  , showAddReceiver : Bool
  }


type Action
  = Volume Float
  | PlayPause
  | ModifyReceiver Receiver.Action
  | ModifyRendition String Rendition.Types.Action
  | ShowAddReceiver Bool
  | NoOp

