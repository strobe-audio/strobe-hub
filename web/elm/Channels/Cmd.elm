module Channels.Cmd exposing (..)

-- import Channels
import Ports
import Msg exposing (Msg)

addChannel : String -> Cmd Msg
addChannel channelName =
    Ports.addChannelRequests channelName
        |> Cmd.map (always Msg.NoOp)
