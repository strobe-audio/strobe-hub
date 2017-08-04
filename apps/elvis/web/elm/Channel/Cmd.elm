module Channel.Cmd exposing (..)

import Root
import Channel
import Ports
import Volume.Cmd
import Msg exposing (Msg)
import ID


playPause : Channel.Model -> Cmd Msg
playPause channel =
    let
        msg =
            ( channel.id, channel.playing )
    in
        Ports.playPauseChanges msg |> Cmd.map (always Msg.NoOp)


skipNext : Channel.Model -> Cmd Msg
skipNext channel =
    Ports.playlistSkipRequests ( channel.id, "next" ) |> Cmd.map (always Msg.NoOp)


volume : Bool -> Channel.Model -> Cmd Msg
volume locked channel =
    Volume.Cmd.channelVolumeChange locked channel |> Cmd.map (always Msg.NoOp)


rename : Channel.Model -> Cmd Msg
rename channel =
    Ports.channelNameChanges ( channel.id, channel.name )
        |> Cmd.map (always Msg.NoOp)


clearPlaylist : Channel.Model -> Cmd Msg
clearPlaylist channel =
    Ports.channelClearPlaylist channel.id
        |> Cmd.map (always Msg.NoOp)


remove : ID.Channel -> Cmd Msg
remove channelId =
    Ports.removeChannelRequests channelId
        |> Cmd.map (always Msg.NoOp)
