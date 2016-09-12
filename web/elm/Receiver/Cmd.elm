module Receiver.Cmd exposing (..)

import ID
import Receiver
import Ports
import Volume.Cmd
import Msg exposing (Msg)


volume : Receiver.Model -> Cmd Msg
volume receiver =
    Volume.Cmd.receiverVolumeChange receiver |> Cmd.map (always Msg.NoOp)


attach : ID.Channel -> ID.Receiver -> Cmd Msg
attach channelId receiverId =
    Ports.attachReceiverRequests ( channelId, receiverId )
        |> Cmd.map (always Msg.NoOp)

rename : Receiver.Model -> Cmd Msg
rename receiver =
    Ports.receiverNameChanges ( receiver.id, receiver.name )
        |> Cmd.map (always Msg.NoOp)
