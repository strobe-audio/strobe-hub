module Receiver.Cmd exposing (..)

import ID
import Receiver
import Ports
import Volume.Cmd


volume : Receiver.Model -> Cmd Receiver.Msg
volume receiver =
    Volume.Cmd.receiverVolumeChange receiver |> Cmd.map (always Receiver.NoOp)


attach : ID.Channel -> ID.Receiver -> Cmd Receiver.Msg
attach channelId receiverId =
    Ports.attachReceiverRequests ( channelId, receiverId )
        |> Cmd.map (always Receiver.NoOp)
