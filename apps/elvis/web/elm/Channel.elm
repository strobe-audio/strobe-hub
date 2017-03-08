module Channel exposing (..)

import Maybe.Extra
import ID
import Input
import Receiver
import Rendition
import Volume as V
import Utils.Touch


type alias Model =
    { id : ID.Channel
    , name : String
    , originalName : String
    , position : Int
    , volume : Float
    , playing : Bool
    , playlist : List Rendition.Model
    , showAddReceiver : Bool
    , editName : Bool
    , editNameInput : Input.Model
    , touches : Utils.Touch.Model
    }


type alias Summary =
    { channel : Model
    , id : ID.Channel
    , playlistDuration : Maybe Int
    , receiverCount : Int
    }


summary : List Receiver.Model -> Model -> Summary
summary receivers channel =
    let
        receiverCount =
            (Receiver.attachedToChannel channel receivers) |> List.length
    in
        { channel = channel
        , id = channel.id
        , receiverCount = receiverCount
        , playlistDuration = (playlistDuration channel)
        }


type Msg
    = Volume V.Msg
    | VolumeChanged Float
    | PlayPause
    | Status ( String, String )
    | ModifyRendition String Rendition.Msg
    | ShowAddReceiver Bool
    | RenditionProgress Rendition.ProgressEvent
    | RenditionChange Rendition.ChangeEvent
    | AddRendition Rendition.State
    | ShowEditName Bool
    | EditName Input.Msg
    | Rename String
    | Renamed String
    | ClearPlaylist
    | Tap (Utils.Touch.E Msg)
    | NoOp


type alias State =
    { id : String
    , name : String
    , position : Int
    , volume : Float
    , playing : Bool
    }


playlistDuration : Model -> Maybe Int
playlistDuration channel =
    let
        playlist =
            channel.playlist

        -- Maybe.withDefault [] (List.tail channel.playlist)
        durations =
            Maybe.Extra.combine (List.map Rendition.duration playlist)

        duration =
            Maybe.map (List.foldr (+) 0) durations
    in
        duration


isActive : Summary -> Bool
isActive summary =
    summary.channel.playing || (summary.receiverCount > 0)
