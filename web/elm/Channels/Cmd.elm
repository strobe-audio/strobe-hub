module Channels.Cmd exposing (..)

import Channels
import Ports


addChannel : String -> Cmd Channels.Msg
addChannel channelName =
  Ports.addChannelRequests channelName
    |> Cmd.map (always Channels.NoOp)
