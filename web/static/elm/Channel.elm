module Channel (..) where

import Receiver
import Rendition
import ID
import Maybe.Extra
import Input


type alias Model =
  { id : ID.Channel
  , name : String
  , originalName : String
  , position : Int
  , volume : Float
  , playing : Bool
  , playlist : List Rendition.Model
  , showAddReceiver : Bool
  , editName : Bool
  , editNameInput : Input.Model
  }


type Action
  = Volume (Maybe Float)
  | VolumeChanged Float
  | PlayPause
  | Status ( String, String )
  | ModifyRendition String Rendition.Action
  | ShowAddReceiver Bool
  | RenditionProgress Rendition.ProgressEvent
  | RenditionChange Rendition.ChangeEvent
  | AddRendition Rendition.Model
  | ShowEditName Bool
  | EditName Input.Action
  | Rename String
  | Renamed String
  | NoOp


type alias State =
  { id : String
  , name : String
  , position : Int
  , volume : Float
  , playing : Bool
  }


playlistDuration : Model -> Maybe Int
playlistDuration channel =
  let
    playlist =
      Maybe.withDefault [] (List.tail channel.playlist)

    durations =
      Maybe.Extra.combine (List.map Rendition.duration playlist)

    duration =
      Maybe.map (List.foldr (+) 0) durations
  in
    duration
