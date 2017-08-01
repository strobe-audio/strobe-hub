module State exposing (..)

import Channel
import Receiver
import Rendition
import ID


type Event
    = Startup BroadcasterState
    | Volume VolumeChangeEvent
    | ReceiverAdd ID.Receiver ID.Channel
    | ReceiverRemove ID.Receiver
    | ReceiverAttach ID.Receiver ID.Channel
    | ReceiverOnline Receiver.State
    | ReceiverRename ID.Receiver String
    | ReceiverMute ID.Receiver Bool
    | ChannelPlayPause ID.Channel Bool
    | ChannelAdd Channel.State
    | ChannelRemove ID.Channel
    | ChannelRename ID.Channel String
    | RenditionProgress Rendition.ProgressEvent
    | RenditionChange Rendition.ChangeEvent
    | RenditionCreate Rendition.State
    | RenditionActive ID.Channel ID.Rendition


type alias BroadcasterState =
    { channels : List Channel.State
    , receivers : List Receiver.State
    , renditions : List Rendition.State
    }


type alias VolumeChangeEvent =
    { id : String
    , target : String
    , volume : Float
    }


type ChannelListMode
    = LibraryMode
    | PlaylistMode


type ViewMode
    = ViewCurrentChannel
    | ViewLibrary
    | ViewSettings


type alias ViewModeString =
    String


viewLabel : ViewMode -> String
viewLabel mode =
    case mode of
        ViewCurrentChannel ->
            "Playlist"

        ViewLibrary ->
            "Library"

        ViewSettings ->
            ""


viewModes : List ViewMode
viewModes =
    [ ViewCurrentChannel
    , ViewLibrary
    , ViewSettings
    ]


serialiseViewMode : ViewMode -> ViewModeString
serialiseViewMode mode =
    (toString mode)


deserialiseViewMode : ViewModeString -> ViewMode
deserialiseViewMode modeString =
    case modeString of
        "ViewCurrentChannel" ->
            ViewCurrentChannel

        "ViewLibrary" ->
            ViewLibrary

        "ViewSettings" ->
            ViewSettings

        _ ->
            ViewCurrentChannel
