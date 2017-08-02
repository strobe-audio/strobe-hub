module Decoders exposing (typedMessageDecoder)

import Dict exposing (Dict)
import Json.Decode exposing (..)
import State
import Channel
import Receiver
import Rendition


typedMessageDecoder : Decoder State.Event
typedMessageDecoder =
    field "__type__" string |> andThen withTypeDecoder


decoderMap : Dict String (Decoder State.Event)
decoderMap =
    Dict.fromList
        [ ( "startup", startupDecoder )
        , ( "volume-change", volumeChangeDecoder )
        , ( "receiver-add", receiverAddDecoder )
        , ( "receiver-remove", receiverRemoveDecoder )
        , ( "receiver-attach", receiverAttachDecoder )
        , ( "receiver-online", receiverOnlineDecoder )
        , ( "receiver-rename", receiverRenameDecoder )
        , ( "receiver-mute", receiverMuteDecoder )
        , ( "channel-play_pause", channelPlayPauseDecoder )
        , ( "channel-add", channelAddDecoder )
        , ( "channel-remove", channelRemoveDecoder )
        , ( "channel-rename", channelRenameDecoder )
        , ( "rendition-progress", renditionProgressDecoder )
        , ( "rendition-create", renditionAddDecoder )
        , ( "rendition-active", renditionActiveDecoder )
        , ( "playlist-change", renditionChangeDecoder )
        ]


withTypeDecoder : String -> Decoder State.Event
withTypeDecoder typ =
    case (Dict.get typ decoderMap) of
        Just decoder ->
            decoder

        Nothing ->
            fail <| "Unknown event type " ++ typ


startupDecoder : Decoder State.Event
startupDecoder =
    (map3
        State.Startup
        (field "channels" (list channelStateDecoder))
        (field "receivers" (list receiverStateDecoder))
        (field "renditions" (list renditionStateDecoder))
    )


volumeChangeDecoder : Decoder State.Event
volumeChangeDecoder =
    map3
        (\id target volume -> State.Volume (State.VolumeChangeEvent id target volume))
        (field "id" string)
        (field "target" string)
        (field "volume" float)


receiverAddDecoder : Decoder State.Event
receiverAddDecoder =
    map2
        State.ReceiverAdd
        (field "receiverId" string)
        (field "channelId" string)


receiverRemoveDecoder : Decoder State.Event
receiverRemoveDecoder =
    map
        State.ReceiverRemove
        (field "receiverId" string)


receiverAttachDecoder : Decoder State.Event
receiverAttachDecoder =
    map2
        State.ReceiverAttach
        (field "receiverId" string)
        (field "channelId" string)


receiverOnlineDecoder : Decoder State.Event
receiverOnlineDecoder =
    map
        State.ReceiverOnline
        receiverStateDecoder


receiverRenameDecoder : Decoder State.Event
receiverRenameDecoder =
    map2
        State.ReceiverRename
        (field "receiverId" string)
        (field "name" string)


receiverMuteDecoder : Decoder State.Event
receiverMuteDecoder =
    map2
        State.ReceiverMute
        (field "receiverId" string)
        (field "muted" bool)


channelPlayPauseDecoder : Decoder State.Event
channelPlayPauseDecoder =
    map2
        State.ChannelPlayPause
        (field "channelId" string)
        (map ((==) "play") (field "status" string))


channelAddDecoder : Decoder State.Event
channelAddDecoder =
    map
        State.ChannelAdd
        channelStateDecoder


channelRemoveDecoder : Decoder State.Event
channelRemoveDecoder =
    map
        State.ChannelRemove
        (field "id" string)


channelRenameDecoder : Decoder State.Event
channelRenameDecoder =
    map2
        State.ChannelRename
        (field "channelId" string)
        (field "name" string)


renditionProgressDecoder : Decoder State.Event
renditionProgressDecoder =
    map
        State.RenditionProgress
        (map4
            Rendition.ProgressEvent
            (field "channelId" string)
            (field "renditionId" string)
            (field "progress" int)
            (field "duration" int)
        )


renditionChangeDecoder : Decoder State.Event
renditionChangeDecoder =
    map
        State.RenditionChange
        (map3
            Rendition.ChangeEvent
            (field "channelId" string)
            (field "removeRenditionIds" (list string))
            (field "activateRenditionId" (nullable string))
        )


renditionAddDecoder : Decoder State.Event
renditionAddDecoder =
    map
        State.RenditionCreate
        renditionStateDecoder


renditionActiveDecoder : Decoder State.Event
renditionActiveDecoder =
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
