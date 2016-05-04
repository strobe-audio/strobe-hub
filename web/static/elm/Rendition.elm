module Rendition (..) where

import ID


type alias SourceMetadata =
  { bit_rate : Maybe Int
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
  }


type alias Source =
  { id : String
  , metadata : SourceMetadata
  }


type alias Model =
  { id : ID.Rendition
  , position : Int
  , playbackPosition : Int
  , sourceId : String
  , channelId : String
  , source : Source
  }


type Action
  = NoOp
  | SkipTo
  | Progress ProgressEvent


type alias ProgressEvent =
  { channelId : String
  , sourceId : String
  , progress : Int
  , duration : Int
  }


type alias ChangeEvent =
  { channelId : String
  , removeSourceIds : List String
  }
