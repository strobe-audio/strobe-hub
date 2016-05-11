module Channel.Effects (..) where

import Effects exposing (Effects, Never)
import Root
import Channel
import Channel.Signals
import Volume.Effects


playPause : Channel.Model -> Effects Channel.Action
playPause channel =
  let
    mailbox =
      Channel.Signals.playPause
  in
    Signal.send mailbox.address ( channel.id, channel.playing )
      |> Effects.task
      |> Effects.map (always Channel.NoOp)


volume : Channel.Model -> Effects Channel.Action
volume channel =
  Volume.Effects.channelVolumeChange channel |> Effects.map (always Channel.NoOp)


rename : Channel.Model -> Effects Channel.Action
rename channel =
  let
    mailbox =
      Channel.Signals.rename
  in
    Signal.send mailbox.address ( channel.id, channel.name )
      |> Effects.task
      |> Effects.map (always Channel.NoOp)
