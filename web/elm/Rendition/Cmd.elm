module Rendition.Cmd exposing (..)

import Rendition
import Ports


skip : Rendition.Model -> Cmd Rendition.Msg
skip rendition =
    Ports.playlistSkipRequests ( rendition.channelId, rendition.id )
        |> Cmd.map (always Rendition.NoOp)

remove : Rendition.Model -> Cmd Rendition.Msg
remove rendition =
    Ports.playlistRemoveRequests ( rendition.channelId, rendition.id )
        |> Cmd.map (always Rendition.NoOp)
