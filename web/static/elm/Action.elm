module Action where

import Types exposing (..)

type Action
  = InitialState Model
  | ReceiverStatus (String, ReceiverStatusEvent)
  | ZoneStatus (String, ZoneStatusEvent)
  | UpdateReceiverVolume Receiver String
  | UpdateZoneVolume Zone String
  | TogglePlayPause (Zone, Bool)
  | SourceProgress SourceProgressEvent
  | SourceChange SourceChangeEvent
  | VolumeChange VolumeChangeEvent
  | NoOp


