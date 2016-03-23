module Types where

type alias Zone =
  { id:       String
  , name:     String
  , position: Int
  , volume:   Float
  , playing:   Bool
  }


type alias Receiver =
  { id:       String
  , name:     String
  , online:   Bool
  , volume:   Float
  , zoneId:   String
  }


type alias Model =
  { zones:     List Zone
  , receivers: List Receiver
  , sources:   List PlaylistEntry
  }


type alias ReceiverStatusEvent =
  { event:      String
  , zoneId:     String
  , receiverId: String
  }


type alias ZoneStatusEvent =
  { event:      String
  , zoneId:     String
  , status:     String
  }

type alias SourceProgressEvent =
  { zoneId: String
  , sourceId: String
  , progress: Int
  , duration: Int
  }


type alias SourceMetadata =
  { bit_rate:     Maybe Int
  , channels:     Maybe Int
  , duration_ms:  Maybe Int
  , extension:    Maybe String
  , filename:     Maybe String
  , mime_type:    Maybe String
  , sample_rate:  Maybe Int
  , stream_size:  Maybe Int
  , album:        Maybe String
  , composer:     Maybe String
  , date:         Maybe String
  , disk_number:  Maybe Int
  , disk_total:   Maybe Int
  , genre:        Maybe String
  , performer:    Maybe String
  , title:        Maybe String
  , track_number: Maybe Int
  , track_total:  Maybe Int
  }

type alias Source =
  { id: String
  , metadata: SourceMetadata
  }

type alias PlaylistEntry =
  { id: String
  , position: Int
  , playbackPosition: Int
  , sourceId: String
  , zoneId:   String
  , source: Source
  }


type alias ZonePlaylist =
  { active: Maybe PlaylistEntry
  , entries: List PlaylistEntry
  }

