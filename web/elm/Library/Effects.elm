module Library.Effects (..) where

import Effects exposing (Effects, Never)
import Debug
import ID
import Library
import Library.Signals
import Task
import Time exposing (Time)


sendAction : ID.Channel -> String -> Effects Library.Action
sendAction channelId action =
  let
    _ =
      Debug.log "sendAction" ( channelId, action )

    mailbox =
      Library.Signals.requests
  in
    Signal.send mailbox.address ( channelId, action )
      |> Effects.task
      |> Effects.map (always Library.NoOp)


requestComplete : Time -> Effects Library.Action
requestComplete delay =
  Task.sleep delay
    |> Task.map (always Library.ActionComplete)
    |> Effects.task
