module Volume.Cmd exposing (..)

import Root
import Channel
import Receiver
import Ports


channelVolumeChange : Bool -> Channel.Model -> Cmd ()
channelVolumeChange locked channel =
    volumeChange "channel" locked channel.id channel


receiverVolumeChange : Bool -> Receiver.Model -> Cmd ()
receiverVolumeChange locked receiver =
    volumeChange "receiver" locked receiver.channelId receiver


receiverMuteChange : Receiver.Model -> Cmd ()
receiverMuteChange receiver =
    Ports.receiverMuteRequests ( receiver.id, receiver.muted )


volumeChange : String -> Bool -> String -> { a | id : String, volume : Float } -> Cmd ()
volumeChange kind locked channelId model =
    Ports.volumeChangeRequests ( kind, locked, channelId, model.id, model.volume )
