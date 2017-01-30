module Library.Cmd exposing (..)

import Debug
import ID
import Library


-- import Library.Signals

import Task
import Time exposing (Time)
import Ports
import Process


sendAction : ID.Channel -> String -> Maybe String -> Cmd Library.Msg
sendAction channelId action query =
    Ports.libraryRequests ( channelId, action, query )
        |> Cmd.map (always Library.NoOp)


requestComplete : Time -> Cmd Library.Msg
requestComplete delay =
    Task.perform
        (always Library.ActionComplete)
        (Process.sleep delay)
