module Channel (..) where

import Receiver
import Rendition
import ID


type alias Model =
  { id : ID.Channel
  , name : String
  , position : Int
  , volume : Float
  , playing : Bool
  , playlist : List Rendition.Model
  , showAddReceiver : Bool
  }


type Action
  = Volume (Maybe Float)
  | PlayPause
  | ModifyRendition String Rendition.Action
  | ShowAddReceiver Bool
  | RenditionProgress Rendition.ProgressEvent
  | RenditionChange Rendition.ChangeEvent
  | NoOp
