module Volume.Cmd exposing (..)

import Root
import Channel
import Receiver
import Ports


channelVolumeChange : Channel.Model -> Cmd ()
channelVolumeChange channel =
    volumeChange "channel" channel


receiverVolumeChange : Receiver.Model -> Cmd ()
receiverVolumeChange receiver =
    volumeChange "receiver" receiver


receiverMuteChange : Receiver.Model -> Cmd ()
receiverMuteChange receiver =
    Ports.receiverMuteRequests ( receiver.id, receiver.muted )


volumeChange : String -> { a | id : String, volume : Float } -> Cmd ()
volumeChange kind model =
    Ports.volumeChangeRequests ( kind, model.id, model.volume )
