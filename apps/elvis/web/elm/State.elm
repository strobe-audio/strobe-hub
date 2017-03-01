module State exposing (..)

import Channel
import Receiver
import Rendition


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
            "Settings"

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
