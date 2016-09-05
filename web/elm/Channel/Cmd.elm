module Channel.Cmd exposing (..)

import Root
import Channel
import Ports
import Volume.Cmd


playPause : Channel.Model -> Cmd Channel.Msg
playPause channel =
  Ports.playPauseChanges ( channel.id, channel.playing )
    |> Cmd.map (always Channel.NoOp)


volume : Channel.Model -> Cmd Channel.Msg
volume channel =
  Volume.Cmd.channelVolumeChange channel |> Cmd.map (always Channel.NoOp)


rename : Channel.Model -> Cmd Channel.Msg
rename channel =
  Ports.channelNameChanges ( channel.id, channel.name )
    |> Cmd.map (always Channel.NoOp)


clearPlaylist : Channel.Model -> Cmd Channel.Msg
clearPlaylist channel =
  Ports.channelClearPlaylist channel.id
    |> Cmd.map (always Channel.NoOp)
