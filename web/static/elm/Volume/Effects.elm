module Volume.Effects where


import Effects exposing (Effects, Never)


import Root
import Channel
import Volume.Signals


channelVolumeChange: Channel.Model -> Effects Root.Action
channelVolumeChange channel =
  volumeChange "channel" channel


receiverVolumeChange: Channel.Model -> Effects Root.Action
receiverVolumeChange channel =
  volumeChange "receiver" channel


volumeChange: String -> { a | id : String, volume : Float } -> Effects Root.Action
volumeChange kind model =
  let
      mailbox = Volume.Signals.volumeChange
  in
      Signal.send mailbox.address (kind, model.id, model.volume)
        |> Effects.task
        |> Effects.map (always Root.NoOp)


