module Root.Cmd exposing (..)

import Root
import Ports


addChannel : String -> Cmd Root.Msg
addChannel channelName =
  Ports.addChannelRequests channelName
    |> Cmd.map (always Root.NoOp)
