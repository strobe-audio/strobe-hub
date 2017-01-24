module Channel.Cmd exposing (..)

import Root
import Channel
import Ports
import Volume.Cmd
import Msg exposing (Msg)


playPause : Channel.Model -> Cmd Msg
playPause channel =
    let
        msg =
            ( channel.id, channel.playing )
    in
        Ports.playPauseChanges msg |> Cmd.map (always Msg.NoOp)


volume : Channel.Model -> Cmd Msg
volume channel =
    Volume.Cmd.channelVolumeChange channel |> Cmd.map (always Msg.NoOp)


rename : Channel.Model -> Cmd Msg
rename channel =
    Ports.channelNameChanges ( channel.id, channel.name )
        |> Cmd.map (always Msg.NoOp)


clearPlaylist : Channel.Model -> Cmd Msg
clearPlaylist channel =
    Ports.channelClearPlaylist channel.id
        |> Cmd.map (always Msg.NoOp)
