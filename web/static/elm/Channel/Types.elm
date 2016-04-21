module Channel.Types where

-- import Types exposing (Action)
import Receiver.Types exposing (Receiver)
import Rendition.Types exposing (Rendition)


type alias Channel =
  { id:       String
  , name:     String
  , position: Int
  , volume:   Float
  , playing:   Bool
  , receivers : List Receiver
  , playlist : List Rendition
  , showAddReceiver : Bool
  }


type ChannelAction
  = Volume Float
  | PlayPause
  | Receiver Receiver.Types.Action
  | ModifyRendition String Rendition.Types.Action
  | ShowAddReceiver Bool
  | NoOp

type alias Context =
  { channelSelect : Signal.Address ()
  , modeSelect : String -> Signal.Address ()
  , actions : Signal.Address ChannelAction
  }

