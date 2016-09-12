module Receivers exposing (..)

import Receiver
import ID


-- type alias Model =
--     { receivers : List Receiver.Model
--     , showAttach : Bool
--     }


-- type Msg
--     = NoOp
--     | VolumeChanged ( ID.Receiver, Float )
--     | Status String ID.Receiver ID.Channel
--     | ShowAttach Bool
--     | Receiver ID.Receiver Receiver.Msg


attachedReceivers : List Receiver.Model -> { a | id : ID.Channel } -> List Receiver.Model
attachedReceivers receivers channel =
    attachedToChannel receivers channel


attachedToChannel : List Receiver.Model -> { a | id : ID.Channel } -> List Receiver.Model
attachedToChannel receivers channel =
    List.filter (\r -> r.channelId == channel.id) receivers


detachedReceivers : List Receiver.Model -> { a | id : ID.Channel } -> List Receiver.Model
detachedReceivers receivers channel =
    List.filter (\r -> r.channelId /= channel.id) receivers


onlineReceivers : List Receiver.Model -> List Receiver.Model
onlineReceivers receivers =
    List.filter .online receivers
