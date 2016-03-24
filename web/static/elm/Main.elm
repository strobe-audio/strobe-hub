module Main where

import String
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import StartApp
import Effects exposing (Effects, Never)
import Task exposing (Task)
import Debug
import Types exposing (..)
import Action exposing (..)
import Source exposing (..)

-- volume sliders go from 0 - this value so we have to convert to a 0-1 range
-- before setting the volume
volumeRangeMax = 1000

init : (Model, Effects Action)
init =
  let
    model = { zones = [], receivers = [], sources = [] }
  in
    (model, Effects.none)


findUpdateReceiver : List Receiver -> String -> (Receiver -> Receiver) -> List Receiver
findUpdateReceiver receivers receiverId updateFunc =
  List.map (\r ->
    if r.id == receiverId then
     (updateFunc r)
    else
      r
  ) receivers


findUpdateZone : List Zone -> String -> (Zone -> Zone) -> List Zone
findUpdateZone zones zoneId updateFunc =
  List.map (\z ->
    if z.id == zoneId then
     (updateFunc z)
    else
      z
  ) zones


receiverOnline : List Receiver -> String -> Bool -> List Receiver
receiverOnline receivers receiverId online =
  findUpdateReceiver receivers receiverId (\r -> { r | online = online })


updateReceiverVolume : Model -> Receiver -> Float -> Model
updateReceiverVolume model receiver volume =
  { model
  | receivers = findUpdateReceiver model.receivers receiver.id (\r -> { r | volume = volume })
  }

updateZoneVolume : Model -> Zone -> Float -> Model
updateZoneVolume model zone volume =
  { model
  | zones = findUpdateZone model.zones zone.id (\z -> { z | volume = volume })
  }


updateReceiverOnlineStatus : Model -> (String, ReceiverStatusEvent) -> Model
updateReceiverOnlineStatus model (event, args) =
  case event of
    "receiver_added" ->
      { model | receivers = (receiverOnline model.receivers args.receiverId True)}
    "receiver_removed" ->
      { model | receivers = (receiverOnline model.receivers args.receiverId False)}
    _ ->
      model


zonePlayPause : List Zone -> String -> String -> List Zone
zonePlayPause zones zoneId status =
  findUpdateZone zones zoneId (\z -> { z | playing = (status == "play") })

updateZoneStatus : Model -> ( String, ZoneStatusEvent ) -> Model
updateZoneStatus model (event, args) =
  case event of
    "zone_play_pause" ->
      { model | zones = (zonePlayPause model.zones args.zoneId args.status) }
    _ ->
      model

translateVolume : String -> Result String Float
translateVolume input =
  case (String.toInt input) of
    Ok vol  -> Ok ((toFloat vol) / volumeRangeMax)
    Err msg -> Err msg


sendReceiverVolumeChange: Receiver -> Float -> Effects Action
sendReceiverVolumeChange receiver volume =
  Signal.send volumeChangeRequestsBox.address ("receiver", receiver.id, volume)
    |> Effects.task
    |> Effects.map (always NoOp)


sendZoneVolumeChange: Zone -> Float -> Effects Action
sendZoneVolumeChange zone volume =
  Signal.send volumeChangeRequestsBox.address ("zone", zone.id, volume)
    |> Effects.task
    |> Effects.map (always NoOp)

sendZoneStatusChange : Zone -> Bool -> Effects Action
sendZoneStatusChange zone playing =
  Signal.send zonePlayPauseRequestsBox.address (zone.id, playing)
    |> Effects.task
    |> Effects.map (always NoOp)


updateZone : Model -> Zone -> (Zone -> Zone) -> Model
updateZone model zone update =
  { model
  | zones = findUpdateZone model.zones zone.id update
  }


updateSourcePlaybackPosition : Model -> SourceProgressEvent -> Model
updateSourcePlaybackPosition model event =
  { model
  | sources = findUpdatePlaylistEntryProgress model.sources event
  }


findUpdatePlaylistEntryProgress : List PlaylistEntry -> SourceProgressEvent -> List PlaylistEntry
findUpdatePlaylistEntryProgress entries event =
  List.map (\e ->
    if e.id == event.sourceId then
     { e | playbackPosition = event.progress }
    else
      e
  ) entries


removeSources : Model -> SourceChangeEvent -> Model
removeSources model event =
  { model
  | sources = List.filter (\s ->
    not (List.member s.id event.removeSourceIds)
  ) model.sources
  }


update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      (model, Effects.none)

    InitialState state ->
      (state, Effects.none)

    ReceiverStatus event ->
      ( updateReceiverOnlineStatus model event
      , Effects.none
      )

    ZoneStatus event ->
      ( updateZoneStatus model event
      , Effects.none
      )

    TogglePlayPause (zone, playing) ->
      ( updateZone model zone (\z -> { z | playing = playing })
      , sendZoneStatusChange zone playing )

    UpdateZoneVolume zone volumeInput ->
      case (translateVolume volumeInput) of
        Ok vol ->
          ( updateZoneVolume model zone vol
          , sendZoneVolumeChange zone vol )
        Err msg ->
          (model, Effects.none)

    UpdateReceiverVolume receiver volumeInput ->
      case (translateVolume volumeInput) of
        Ok vol ->
          ( updateReceiverVolume model receiver vol
          , sendReceiverVolumeChange receiver vol )
        Err msg ->
          (model, Effects.none)

    SourceProgress event ->
      ( updateSourcePlaybackPosition model event
      , Effects.none)

    SourceChange event ->
      ( removeSources model event
      , Effects.none)


zoneReceivers : Model -> Zone -> List Receiver
zoneReceivers model zone =
  List.filter (\r -> r.zoneId == zone.id) model.receivers

receiverInZone : Signal.Address Action -> Receiver -> Html
receiverInZone address receiver =
  div [ classList [("receiver", True), ("receiver--online", receiver.online), ("receiver--offline", not receiver.online)] ] [
    div [] [ text receiver.name ]
  , volumeControl address receiver.volume (UpdateReceiverVolume receiver)
  ]




volumeControl : Signal.Address Action -> Float -> (String -> Action) -> Html
volumeControl address volume message =
  div [ class "volume-control" ] [
    i [ class "volume off icon", onClick address (message "0") ] []
  , input [
      type' "range"
    , Html.Attributes.min "0"
    , Html.Attributes.max (toString volumeRangeMax)
    , step "1"
    , value (toString (volume * volumeRangeMax))
    , on "input" targetValue (Signal.message address << message)
    ] []
  , i [ class "volume up icon", onClick address (message (toString volumeRangeMax)) ] []
  ]


zonePlayPauseButton : Signal.Address Action -> Zone -> Html
zonePlayPauseButton address zone =
  i [
    classList [("icon", True), ("play", not zone.playing), ("pause", zone.playing)]
  , onClick address (TogglePlayPause ( zone, not(zone.playing) ))
  ] []


zonePanel : Signal.Address Action -> Model -> Zone -> Html
zonePanel address model zone =
  let
      playlist = (zonePlaylist model zone)
  in
    div [ class "zone six wide column" ] [
      div [ class "ui card" ] [
        div [ class "content" ] [
          div [ class "header" ] [
            (zonePlayPauseButton address zone)
          , (text zone.name)
          , (volumeControl address zone.volume (UpdateZoneVolume zone))
          , (activePlaylistEntry address playlist.active)
          ]
        ]
      , div [ class "content" ] (List.map (receiverInZone address) (zoneReceivers model zone))
      , div [ class "content" ] (List.map (playlistEntry address)  playlist.entries)
      ]
    ]


view : Signal.Address Action -> Model -> Html
view address model =
  div [ class "ui container" ] [
    div [ class "zones ui grid" ] (List.map (zonePanel address model) model.zones)
  ]


incomingActions : Signal Action
incomingActions =
  Signal.map InitialState initialState


receiverStatusActions : Signal Action
receiverStatusActions =
  Signal.map ReceiverStatus receiverStatus


zoneStatusActions : Signal Action
zoneStatusActions =
  Signal.map ZoneStatus zoneStatus


sourceProgressActions : Signal Action
sourceProgressActions =
  Signal.map SourceProgress sourceProgress

sourceChangeActions : Signal Action
sourceChangeActions =
  Signal.map SourceChange sourceChange

app =
  StartApp.start
    { init = init
    , update = update
    , view = view
    , inputs = [ incomingActions
               , receiverStatusActions
               , zoneStatusActions
               , sourceProgressActions
               , sourceChangeActions
               ]
    }


main : Signal Html
main =
  app.html

port tasks : Signal (Task Never ())
port tasks =
  app.tasks

port initialState : Signal Model

port receiverStatus : Signal ( String, ReceiverStatusEvent )

port zoneStatus : Signal ( String, ZoneStatusEvent )

port volumeChanges : Signal ( String, String, Float )
port volumeChanges =
  volumeChangeRequestsBox.signal

port playPauseChanges : Signal ( String, Bool )
port playPauseChanges =
  zonePlayPauseRequestsBox.signal

port sourceProgress : Signal SourceProgressEvent

port sourceChange : Signal SourceChangeEvent

volumeChangeRequestsBox : Signal.Mailbox ( String, String, Float )
volumeChangeRequestsBox =
  Signal.mailbox ( "", "", 0.0 )

zonePlayPauseRequestsBox : Signal.Mailbox ( String, Bool )
zonePlayPauseRequestsBox =
  Signal.mailbox ( "", False )
