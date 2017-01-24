module Root exposing (..)

import List.Extra
import Json.Decode as Json
import Time exposing (Time)


--

import Library
import Channel
import Receiver
import Rendition
import ID
import Input
import Utils.Touch
import Notification
import State
import Msg exposing (Msg)


type alias Model =
    { connected : Bool
    , channels : List Channel.Model
    , receivers : List Receiver.Model
    , showAddChannel : Bool
    , newChannelInput : Input.Model
    , showAttachReceiver : Bool
    , activeChannelId : Maybe ID.Channel
    , listMode : State.ChannelListMode
    , showPlaylistAndLibrary : Bool
    , library : Library.Model
    , touches : Utils.Touch.Model
    , animationTime : Maybe Time
    , notifications : List (Notification.Model Msg)
    -- NEW
    , viewMode : State.ViewMode
    , showChannelControl : Bool
    , savedState : Maybe SavedState
    }


type alias SavedState =
    { activeChannelId : ID.Channel
    }

type alias ReceiverStatusEvent =
    { channelId : String
    , receiverId : String
    }


type alias ChannelStatusEvent =
    { channelId : String
    , status : String
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
                State.LibraryMode ->
                    False

                State.PlaylistMode ->
                    True
