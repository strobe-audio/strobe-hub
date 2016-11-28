module Rendition exposing (..)

import ID


type alias Source =
    { id : String
    , bit_rate : Maybe Int
    , channels : Maybe Int
    , duration_ms : Maybe Int
    , extension : Maybe String
    , filename : Maybe String
    , mime_type : Maybe String
    , sample_rate : Maybe Int
    , stream_size : Maybe Int
    , album : Maybe String
    , composer : Maybe String
    , date : Maybe String
    , disk_number : Maybe Int
    , disk_total : Maybe Int
    , genre : Maybe String
    , performer : Maybe String
    , title : Maybe String
    , track_number : Maybe Int
    , track_total : Maybe Int
    , cover_image : String
    }


type alias Model =
    { id : ID.Rendition
    , position : Int
    , playbackPosition : Int
    , sourceId : String
    , channelId : String
    , source : Source
    }


type Msg
    = NoOp
    | PlayPause
    | SkipTo
    | Progress ProgressEvent


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
