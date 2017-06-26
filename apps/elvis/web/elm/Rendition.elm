module Rendition exposing (..)

import ID
import Utils.Touch


type alias Source =
    { id : String
    , album : Maybe String
    , composer : Maybe String
    , duration_ms : Maybe Int
    , genre : Maybe String
    , performer : Maybe String
    , title : Maybe String
    , cover_image : String
    }


type alias State =
    { id : ID.Rendition
    , position : Int
    , playbackPosition : Int
    , sourceId : String
    , channelId : String
    , source : Source
    }


type alias Model =
    { id : ID.Rendition
    , position : Int
    , playbackPosition : Int
    , sourceId : String
    , channelId : String
    , source : Source
    , touches : Utils.Touch.Model
    , swipe : Maybe Utils.Touch.SwipeModel
    , menu : Bool
    , removeInProgress : Bool
    }


type Msg
    = NoOp
    | PlayPause
    | SkipTo
    | Progress ProgressEvent
    | Swipe (Utils.Touch.E Msg)
    | Tap (Utils.Touch.E Msg)
    | CloseMenu
    | Remove


type alias ProgressEvent =
    { channelId : String
    , renditionId : String
    , progress : Int
    , duration : Int
    }


type alias ChangeEvent =
    { channelId : String
    , removeRenditionIds : List String
    }


duration : Model -> Maybe Int
duration rendition =
    Maybe.map (\duration -> duration - rendition.playbackPosition)
        rendition.source.duration_ms
