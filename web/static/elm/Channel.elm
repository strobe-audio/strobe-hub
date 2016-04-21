module Channel where

-- import Types exposing (Action)
import Receiver
import Rendition

type alias ID = String

type alias Model =
  { id : ID
  , name : String
  , position : Int
  , volume : Float
  , playing : Bool
  , receivers : List Receiver.Model
  , playlist : List Rendition.Model
  , showAddReceiver : Bool
  }


type Action
  = Volume Float
  | PlayPause
  | ModifyReceiver Receiver.Action
  | ModifyRendition String Rendition.Action
  | ShowAddReceiver Bool
  | NoOp

