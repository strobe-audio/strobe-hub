module Receivers exposing (..)

import Receiver
import ID


type alias Model =
  { receivers : List Receiver.Model
  , showAttach : Bool
  }


type Msg
  = NoOp
  | VolumeChanged ( ID.Receiver, Float )
  | Status String ID.Receiver ID.Channel
  | ShowAttach Bool
  | Receiver ID.Receiver Receiver.Msg


attachedReceivers : Model -> { a | id : ID.Channel } -> List Receiver.Model
attachedReceivers model channel =
  attachedToChannel model.receivers channel

attachedToChannel : List Receiver.Model -> { a | id : ID.Channel } -> List Receiver.Model
attachedToChannel receivers channel =
    List.filter (\r -> r.channelId == channel.id) receivers


detachedReceivers : Model -> { a | id : ID.Channel } -> List Receiver.Model
detachedReceivers model channel =
    List.filter (\r -> r.channelId /= channel.id) model.receivers

onlineReceivers : Model -> List Receiver.Model
onlineReceivers model =
  List.filter .online model.receivers
