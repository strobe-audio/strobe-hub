module Root exposing (..)

import List.Extra
import Json.Decode as Json


--

import Library
import Channel
import Receiver
import Rendition
import ID
import Input
import Utils.Touch


type alias Model =
    { connected : Bool
    , channels : List Channel.Model
    , receivers : List Receiver.Model
    , showAddChannel : Bool
    , newChannelInput : Input.Model
    , showChannelSwitcher : Bool
    , showAttachReceiver : Bool
    , activeChannelId : Maybe ID.Channel
    , listMode : ChannelListMode
    , showPlaylistAndLibrary : Bool
    , library : Library.Model
    , touches : Utils.Touch.Model
    }


type ChannelListMode
    = LibraryMode
    | PlaylistMode


type alias BroadcasterState =
    { channels : List Channel.State
    , receivers : List Receiver.State
    , renditions : List Rendition.State
    }


type alias ReceiverStatusEvent =
    { channelId : String
    , receiverId : String
    }


type alias ChannelStatusEvent =
    { channelId : String
    , status : String
    }


type alias VolumeChangeEvent =
    { id : String
    , target : String
    , volume : Float
    }


activeChannel : Model -> Maybe Channel.Model
activeChannel model =
    case model.activeChannelId of
        Nothing ->
            Nothing

        Just id ->
            List.Extra.find (\c -> c.id == id) model.channels


playlistVisible : Model -> Bool
playlistVisible model =
    case model.showPlaylistAndLibrary of
        True ->
            True

        False ->
            case model.listMode of
                LibraryMode ->
                    False

                PlaylistMode ->
                    True


overlayActive : Model -> Bool
overlayActive model =
    model.showChannelSwitcher
