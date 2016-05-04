module Volume.Effects (..) where

import Effects exposing (Effects, Never)
import Root
import Channel
import Receiver
import Volume.Signals


channelVolumeChange : Channel.Model -> Effects ()
channelVolumeChange channel =
  volumeChange "channel" channel


receiverVolumeChange : Receiver.Model -> Effects ()
receiverVolumeChange receiver =
  volumeChange "receiver" receiver


volumeChange : String -> { a | id : String, volume : Float } -> Effects ()
volumeChange kind model =
  let
    mailbox =
      Volume.Signals.volumeChange
  in
    Signal.send mailbox.address ( kind, model.id, model.volume )
      |> Effects.task
