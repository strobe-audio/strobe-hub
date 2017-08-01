module Decoders exposing (decodeTypedMessage)

import Json.Decode exposing (..)
import State
import Channel
import Receiver
import Rendition


decodeTypedMessage : Decoder State.Event
decodeTypedMessage =
    field "__type__" string |> andThen decodeWithType


decodeWithType : String -> Decoder State.Event
decodeWithType typ =
    case typ of
        "startup" ->
            decodeStartup

        "volume-change" ->
            decodeVolumeChange

        "receiver-add" ->
            decodeReceiverAdd

        "receiver-remove" ->
            decodeReceiverRemove

        "receiver-attach" ->
            decodeReceiverAttach

        "receiver-online" ->
            decodeReceiverOnline

        "receiver-rename" ->
            decodeReceiverRename

        "receiver-mute" ->
            decodeReceiverMute

        "channel-play_pause" ->
            decodeChannelPlayPause

        "channel-add" ->
            decodeChannelAdd

        "channel-remove" ->
            decodeChannelRemove

        "channel-rename" ->
            decodeChannelRename

        "rendition-progress" ->
            decodeRenditionProgress

        "rendition-change" ->
            decodeRenditionChange

        "rendition-create" ->
            decodeRenditionAdd

        "rendition-active" ->
            decodeRenditionActive

        unknown ->
            fail ("Unknown event type " ++ unknown)


decodeStartup : Decoder State.Event
decodeStartup =
    let
        constructor a b c =
            State.Startup (State.BroadcasterState a b c)
    in
        (map3
            constructor
            (field "channels" (list channelStateDecoder))
            (field "receivers" (list receiverStateDecoder))
            (field "renditions" (list renditionStateDecoder))
        )


decodeVolumeChange : Decoder State.Event
decodeVolumeChange =
    map3
        (\id target volume -> State.Volume (State.VolumeChangeEvent id target volume))
        (field "id" string)
        (field "target" string)
        (field "volume" float)


decodeReceiverAdd : Decoder State.Event
decodeReceiverAdd =
    map2
        State.ReceiverAdd
        (field "receiverId" string)
        (field "channelId" string)


decodeReceiverRemove : Decoder State.Event
decodeReceiverRemove =
    map
        State.ReceiverRemove
        (field "receiverId" string)


decodeReceiverAttach : Decoder State.Event
decodeReceiverAttach =
    map2
        State.ReceiverAttach
        (field "receiverId" string)
        (field "channelId" string)


decodeReceiverOnline : Decoder State.Event
decodeReceiverOnline =
    map
        State.ReceiverOnline
        receiverStateDecoder


decodeReceiverRename : Decoder State.Event
decodeReceiverRename =
    map2
        State.ReceiverRename
        (field "receiverId" string)
        (field "name" string)


decodeReceiverMute : Decoder State.Event
decodeReceiverMute =
    map2
        State.ReceiverMute
        (field "receiverId" string)
        (field "muted" bool)


decodeChannelPlayPause : Decoder State.Event
decodeChannelPlayPause =
    map2
        State.ChannelPlayPause
        (field "channelId" string)
        (map ((==) "play") (field "status" string))


decodeChannelAdd : Decoder State.Event
decodeChannelAdd =
    map
        State.ChannelAdd
        channelStateDecoder


decodeChannelRemove : Decoder State.Event
decodeChannelRemove =
    map
        State.ChannelRemove
        (field "id" string)


decodeChannelRename : Decoder State.Event
decodeChannelRename =
    map2
        State.ChannelRename
        (field "channelId" string)
        (field "name" string)


decodeRenditionProgress : Decoder State.Event
decodeRenditionProgress =
    map
        State.RenditionProgress
        (map4
            Rendition.ProgressEvent
            (field "channelId" string)
            (field "renditionId" string)
            (field "progress" int)
            (field "duration" int)
        )


decodeRenditionChange : Decoder State.Event
decodeRenditionChange =
    map
        State.RenditionChange
        (map3
            Rendition.ChangeEvent
            (field "channelId" string)
            (field "removeRenditionIds" (list string))
            (field "activateRenditionId" (nullable string))
        )


decodeRenditionAdd : Decoder State.Event
decodeRenditionAdd =
    map
        State.RenditionCreate
        renditionStateDecoder


decodeRenditionActive : Decoder State.Event
decodeRenditionActive =
    map2
        State.RenditionActive
        (field "channelId" string)
        (field "renditionId" string)


channelStateDecoder : Decoder Channel.State
channelStateDecoder =
    (map5
        Channel.State
        (field "id" string)
        (field "name" string)
        (field "position" int)
        (field "volume" float)
        (field "playing" bool)
    )


receiverStateDecoder : Decoder Receiver.State
receiverStateDecoder =
    (map6
        Receiver.State
        (field "id" string)
        (field "name" string)
        (field "online" bool)
        (field "volume" float)
        (field "muted" bool)
        (field "channelId" string)
    )


renditionStateDecoder : Decoder Rendition.State
renditionStateDecoder =
    (map7
        Rendition.State
        (field "id" string)
        (field "nextId" string)
        (field "playbackPosition" int)
        (field "sourceId" string)
        (field "channelId" string)
        (field "source" sourceDecoder)
        (field "active" bool)
    )


sourceDecoder : Decoder Rendition.Source
sourceDecoder =
    (map8
        Rendition.Source
        (field "id" string)
        (field "album" (nullable string))
        (field "composer" (nullable string))
        (field "duration_ms" (nullable int))
        (field "genre" (nullable string))
        (field "performer" (nullable string))
        (field "title" (nullable string))
        (field "cover_image" string)
    )
