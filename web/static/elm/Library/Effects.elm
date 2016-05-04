module Library.Effects (..) where

import Effects exposing (Effects, Never)
import Debug
import ID
import Library
import Library.Signals


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
