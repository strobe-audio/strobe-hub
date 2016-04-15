module Main where

import String
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import StartApp
import Effects exposing (Effects, Never)
import Task exposing (Task)
import Debug exposing (log)
import Json.Decode exposing ((:=))
import Types exposing (..)
import Source exposing (..)
import Library


-- volume sliders go from 0 - this value so we have to convert to a 0-1 range
-- before setting the volume
volumeRangeMax = 1000

initZoneUIState : Zone -> ZoneUIState
initZoneUIState zone =
  { id = zone.id
  , showAddReceivers = False
  , showRename = False
  }


initReceiverUIState : Receiver -> ReceiverUIState
initReceiverUIState receiver =
  { id = receiver.id
  , showRename = False
  }


initUIState : List Zone -> List Receiver -> UIState
initUIState zones receivers =
  { zones = List.map initZoneUIState zones
  , receivers = List.map initReceiverUIState receivers
  }

init : (Model, Effects Action)
init =
  let
    model =
      { zones = []
      , receivers = []
      , sources = []
      , library = Library.init
      , ui = initUIState [] []
      , activeZoneId = ""
      , activeState = "channel"
      }
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


updateReceiverStatus : Model -> (String, ReceiverStatusEvent) -> Model
updateReceiverStatus model (event, args) =
  case event of
    "receiver_added" ->
      { model | receivers =
        findUpdateReceiver model.receivers args.receiverId (\receiver ->
          { receiver | online = True, zoneId = args.zoneId }
        )
      }
    "receiver_removed" ->
      { model | receivers =
        findUpdateReceiver model.receivers args.receiverId (\receiver ->
          { receiver | online = False, zoneId = args.zoneId }
        )
      }
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

sendPlaylistSkipChange : PlaylistEntry -> Effects Action
sendPlaylistSkipChange entry =
  Signal.send playlistSkipRequestsBox.address ( entry.zoneId, entry.id )
    |> Effects.task
    |> Effects.map (always NoOp)


sendAttachReceiverChange : Zone -> Receiver -> Effects Action
sendAttachReceiverChange zone receiver =
  Signal.send attachReceiverRequestsBox.address (zone.id, receiver.id)
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
  let
      remove = (Debug.log "remove" event.removeSourceIds)
      present = Debug.log "members" (List.map (\s -> (s.position, s.id)) model.sources)
      isMember = (\id -> ( List.member id event.removeSourceIds ))
      sources = List.filter (\s -> (not (isMember s.id))) model.sources

      sourcesInZone = (\z s -> List.filter (\e -> e.zoneId == z.id) s)
      zoneSources = List.map (\z ->
          (sourcesInZone z sources) |> ( List.indexedMap (\p s -> { s | position = p }) )
        ) model.zones
      allSources = List.concat zoneSources
      _ = Debug.log "remainng" (List.map (\s -> (s.position, s.id)) allSources)
  in
      { model | sources = allSources }

addPlayListEntry : Model -> PlaylistEntry -> Model
addPlayListEntry model entry =
  let
      _ = Debug.log "01 add" entry.id
      present = Debug.log "02 members" (List.map (\s -> (s.position, s.id)) model.sources)
      before = List.take entry.position model.sources
      after = entry :: (List.drop entry.position model.sources)
      sources = (List.append before after)
      ids = Debug.log "03 new sources" (List.map (\s -> (s.position, s.id)) sources)
  in
    { model | sources = sources }

showAddReceiver : Model -> Zone -> Bool -> Model
showAddReceiver model zone show =
  let
      modelUI = model.ui
      ui = { modelUI | zones = updateZoneUIState modelUI.zones zone (\ui -> { ui | showAddReceivers = show } ) }
  in
    { model | ui = ui }

updateZoneUIState : List ZoneUIState -> Zone -> ( ZoneUIState -> ZoneUIState ) -> List ZoneUIState
updateZoneUIState states zone update =
  List.map (\ui ->
    if ui.id == zone.id then
       update ui
    else
      ui
  ) states


uiStateForZone : Model -> Zone -> Maybe ZoneUIState
uiStateForZone model zone =
  List.filter (\ui -> ui.id == zone.id) model.ui.zones
  |> List.head


update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp ->
      (model, Effects.none)

    InitialState state ->
      let
        initialState = { state
        | ui = initUIState state.zones state.receivers
        , library = Library.init
        }
      in
        (initialState, Effects.none)

    ReceiverStatus event ->
      ( updateReceiverStatus model event
      , Effects.none
      )

    ZoneStatus event ->
      ( updateZoneStatus model event
      , Effects.none
      )

    TogglePlayPause (zone, playing) ->
      ( updateZone model zone (\z -> { z | playing = playing })
      , sendZoneStatusChange zone playing )

    UpdateZoneVolume zone volume ->
      ( updateZoneVolume model zone volume
      , sendZoneVolumeChange zone volume )

    UpdateReceiverVolume receiver volume ->
      ( updateReceiverVolume model receiver volume
      , sendReceiverVolumeChange receiver volume )

    SourceProgress event ->
      ( updateSourcePlaybackPosition model event
      , Effects.none)

    SourceChange event ->
      ( removeSources model event
      , Effects.none)

    VolumeChange event ->
      let
          updatedModel = case event.target of
            "receiver" ->
              { model
              | receivers = findUpdateReceiver model.receivers event.id (\r -> { r | volume = event.volume })
              }
            "zone" ->
              { model
              | zones = findUpdateZone model.zones event.id (\z -> { z | volume = event.volume })
              }
            _ ->
              model
      in
        ( updatedModel
        , Effects.none)

    PlayListAddition playlistEntry ->
      ( addPlayListEntry model playlistEntry
      , Effects.none)

    PlaylistSkip playlistEntry ->
      (model, sendPlaylistSkipChange playlistEntry)

    ShowAddReceiver (zone, state) ->
      (showAddReceiver model zone state
      , Effects.none)

    AttachReceiver zone receiver ->
      (model, sendAttachReceiverChange zone receiver)


    LibraryRegistration node ->
      ( { model | library = Library.add model.library node }
      , Effects.none )


    Library libraryAction ->
      let
          (library, effect) = Library.update libraryAction model.library
      in
          ({ model | library = library },
           (Effects.map Library effect)
          )

    SetMode mode ->
      ( { model | activeState = mode }, Effects.none)



receiversAttachedToZone : Model -> Zone -> List Receiver
receiversAttachedToZone model zone =
  List.filter (\r -> r.zoneId == zone.id) model.receivers


receiversNotAttachedToZone : Model -> Zone -> List Receiver
receiversNotAttachedToZone model zone =
  List.filter (\r -> r.zoneId /= zone.id) model.receivers


receiverInZone : Signal.Address Action -> Receiver -> Html
receiverInZone address receiver =
  div [ classList [("receiver", True), ("receiver--online", receiver.online), ("receiver--offline", not receiver.online)] ] [
    volumeControl address receiver.volume receiver.name (UpdateReceiverVolume receiver)
  ]




volumeControl : Signal.Address Action -> Float -> String -> (Float -> Action) -> Html
volumeControl address volume label message =
  let
      handler buttons offset width =
        let
            m = case buttons of
              1 ->
                 message ( (toFloat offset) / (toFloat width) )
              _ ->
                NoOp
        in
          Signal.message address m

      options = { stopPropagation = False, preventDefault = False }
      mousemove = onWithOptions
        "mousemove"
        options
        (Json.Decode.object3 (,,)
          ("buttons" := Json.Decode.int)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(m, x, w) -> handler m x w)
      mousedown = onWithOptions
        "mousedown"
        options
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) -> handler 1 x w)
      touchstart = onWithOptions
        "touchstart"
        { options | preventDefault = False }
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) -> handler 1 (Debug.log "start" x) w)
      touchend = onWithOptions
        "touchend"
        { options | preventDefault = False }
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) -> handler 1 (Debug.log "end" x) w)
      touchmove = onWithOptions
        "touchmove"
        { options | preventDefault = False }
        (Json.Decode.object2 (,)
          ("offsetX" := Json.Decode.int)
          (Json.Decode.at ["target", "offsetWidth"] Json.Decode.int )
        )
        (\(x, w) ->  handler 1 (Debug.log "move" x) w)
  in
      div [ class "block-group volume-control" ]
          [ div [ class "block volume-mute-btn fa fa-volume-off", onClick address (message 0.0) ] []
          , div [ class "block volume",  mousemove, touchmove, mousedown, touchstart, touchend]
              [ div [ class "volume-level", style [("width", (toString (volume * 100)) ++ "%")] ] []
              , div [ class "volume-label" ] [ text label ]
              ]
          , div [ class "block volume-full-btn fa fa-volume-up", onClick address (message 1.0) ] []
          ]


zonePlayPauseButton : Signal.Address Action -> Zone -> Html
zonePlayPauseButton address zone =
  i [
    classList [("icon", True), ("play", not zone.playing), ("pause", zone.playing)]
  , onClick address (TogglePlayPause ( zone, not(zone.playing) ))
  ] []


attachReceiverList : Signal.Address Action -> Zone -> List Receiver -> Html
attachReceiverList address zone receivers =
  div [] [
    div [] [ button [ class "tiny fluid ui button", onClick address (ShowAddReceiver ( zone, False )) ] [ text "Done" ] ]
  , div [ class "ui list" ] (List.map (\r ->
      div [ class "item" ] [
        button [ class "tiny fluid ui labeled icon green button", onClick address ( AttachReceiver zone r ) ] [
          i [ class "plus icon" ] []
        , text r.name
        ]
      ]
    ) receivers)
  ]

zoneReceiverList : Signal.Address Action -> Model -> Zone -> Html
zoneReceiverList address model zone =
  let
      attached = (receiversAttachedToZone model zone)
      detached = (receiversNotAttachedToZone model zone)
      showAdd = case uiStateForZone model zone of
        Just state ->
          state.showAddReceivers
        Nothing ->
          False
      addButton = case List.length detached of
        0 ->
          div [] []
        _ ->
          if showAdd then
            attachReceiverList address zone detached
          else
            div [ class "content", onClick address (ShowAddReceiver ( zone, True )) ] [
              button [ class "tiny fluid ui button" ] [ text "Add receivers" ]
            ]
  in
     div [ class "content" ] [
       addButton
     , div [ class "content" ] (List.map (receiverInZone address) attached)
     ]



-- zonePanel : Signal.Address Action -> Model -> Zone -> Html
-- zonePanel address model zone =
--   let
--       playlist = (zonePlaylist model zone)
--   in
--     div [ id zone.id, class "zone eight wide column" ] [
--       div [ class "ui card" ] [
--         div [ class "content" ] [
--           div [ class "header" ] [
--             (zonePlayPauseButton address zone)
--           , (text zone.name)
--           -- , (volumeControl address zone.volume (UpdateZoneVolume zone))
--           -- , (activePlaylistEntry address playlist.active)
--           ]
--         ]
--       , (zoneReceiverList address model zone)
--       , div [] [
--           div [ class "block-group" ] (List.map (playlistEntry address)  playlist.entries)
--         ]
--       ]
--     ]

activeZone : Model -> Maybe Zone
activeZone model =
  List.head ( List.filter ( \z -> z.id == model.activeZoneId ) model.zones )

modeSelectorPanel : Signal.Address Action -> Model -> Html
modeSelectorPanel address model =
  case activeZone model of
    Nothing ->
      div [] []
    Just zone ->
      let
          button = case model.activeState of
            "library" ->
              div [ class "block mode-switch", onClick address (SetMode "channel") ] [
                i [ class "fa fa-bullseye" ] []
              ]
            "channel" ->
              div [ class "block mode-switch", onClick address (SetMode "library") ] [
                i [ class "fa fa-music" ] []
              ]
            _ ->
              div [] []
      in
      div [ class "block-group mode-selector" ] [
        div [ class "block mode-channel-select" ] [
          i [ class "fa fa-bullseye" ] []
        ]
      , div [ class "block mode-channel" ] [
          (volumeControl address zone.volume zone.name (UpdateZoneVolume zone))
        ]
        , button
      ]


playingSong : Signal.Address Action -> Zone -> Maybe PlaylistEntry -> Html
playingSong address zone maybeEntry =
  case maybeEntry of
    Nothing ->
      div [] []
    Just entry ->
      div [ id entry.id, class "player" ]
        [ div [ class "player-icon" ]
          [ img [ src "/images/cover.jpg", alt "", onClick address ( TogglePlayPause (zone, not(zone.playing)) ) ] []
          , div [ class "player-song" ]
            [ div [ class "player-title" ]
              [ text (entryTitle entry)
              , div [ class "block player-duration duration" ] [ text (duration entry) ]
              ]
            , div [ class "player-meta" ]
              [ div [ class "player-artist" ] [ text (entryPerformer entry) ]
              , div [ class "player-album" ] [ text (entryAlbum entry) ]
              ]
            ]
          ]
        ]


duration : PlaylistEntry -> String
duration entry =
  case entry.source.metadata.duration_ms of
    Nothing ->
      ""
    Just duration ->
      let
          totalSeconds = (duration // 1000)
          hours = (totalSeconds // 3600) % 24
          minutes = (totalSeconds // 60) % 60
          seconds = totalSeconds % 60
          values = List.map (String.padLeft 2 '0') (List.map toString [hours, minutes, seconds])

      in
          List.foldr (++) "" (List.intersperse ":" values)


playbackProgress : Signal.Address Action -> Maybe PlaylistEntry -> Html
playbackProgress address activeEntry =
  case activeEntry of
    Nothing ->
      div [ ] [ ]
    Just entry ->
      case entry.source.metadata.duration_ms of
        Nothing ->
          div [ ] [ ]
        Just duration ->
          let
              percent = 100.0 * (toFloat entry.playbackPosition) / (toFloat duration)
              progressStyle = [ ("width", (toString percent) ++ "%") ]
          in
            div [ class "progress" ] [
              div [ class "progress-complete", style progressStyle ] [ ]
            ]



activeZonePanel : Signal.Address Action -> Model -> List Html
activeZonePanel address model =
  case activeZone model of
    Nothing ->
      []
    Just zone ->
      let
        playlist = (zonePlaylist model zone)
      in
        [ playingSong address zone playlist.active
        , playbackProgress address playlist.active
        ]

zoneModePanel : Signal.Address Action -> Model -> List Html
zoneModePanel address model =
  case activeZone model of
    Nothing ->
      []
    Just zone ->
      let
        playlist = (zonePlaylist model zone)
        playlistdebug = (List.map (\e -> e.id) playlist.entries)
      in
        [ div [ class "divider" ] [ text "Receivers" ]
        , zoneReceiverList address model zone
        , div [ class "divider" ] [ text "Playlist" ]
        , div [ class "block-group channel-playlist" ] (List.map (playlistEntry address)  playlist.entries)
        ]


libraryModePanel : Signal.Address Action -> Model -> List Html
libraryModePanel address model =
  [ Library.root (Signal.forwardTo address Library) model.library ]

view : Signal.Address Action -> Model -> Html
view address model =
  div [ classList [("elvis", True), ("elvis-mode-channel", model.activeState == "channel"), ("elvis-mode-library", model.activeState == "library")] ] [
    div [ class "channels" ] [
      div [ class "mode-wrapper" ] [
        (modeSelectorPanel address model)
        , div [ class "zone-view" ] (activeZonePanel address model)
        , div [ class "mode-view" ] [
          -- this should be a view dependent on the current view mode (current zone, library, zone chooser)
          div [ id "channel" ] (zoneModePanel address model)
        ]
      ]
    ]
  , div [ id "library" ] ( libraryModePanel address model )

    -- div [ class "ui grid" ] [
    --   div [ class "libraries six wide column" ] [ Library.root (Signal.forwardTo address Library) model.library ]
    --   , div [ class "zones ten wide column" ]
    --     [ div [ class "ui grid" ]
    --       (List.map (zonePanel address model) model.zones)
    --   ]
    -- ]
  ]



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
               , volumeChangeActions
               , playListAdditionActions
               , libraryRegistrationActions
               , libraryResponseActions
               ]
    }


main : Signal Html
main =
  app.html

port tasks : Signal (Task Never ())
port tasks =
  app.tasks


port initialState : Signal Model

incomingActions : Signal Action
incomingActions =
  Signal.map InitialState initialState


port receiverStatus : Signal ( String, ReceiverStatusEvent )

receiverStatusActions : Signal Action
receiverStatusActions =
  Signal.map ReceiverStatus receiverStatus


port zoneStatus : Signal ( String, ZoneStatusEvent )

zoneStatusActions : Signal Action
zoneStatusActions =
  Signal.map ZoneStatus zoneStatus


port sourceProgress : Signal SourceProgressEvent

sourceProgressActions : Signal Action
sourceProgressActions =
  Signal.map SourceProgress sourceProgress


port sourceChange : Signal SourceChangeEvent

sourceChangeActions : Signal Action
sourceChangeActions =
  Signal.map SourceChange sourceChange


port volumeChange : Signal VolumeChangeEvent

volumeChangeActions : Signal Action
volumeChangeActions =
  Signal.map VolumeChange volumeChange


port playlistAddition : Signal PlaylistEntry

playListAdditionActions : Signal Action
playListAdditionActions =
  Signal.map PlayListAddition playlistAddition


port libraryRegistration : Signal Library.Node

libraryRegistrationActions : Signal Action
libraryRegistrationActions =
  Signal.map LibraryRegistration libraryRegistration


port libraryResponse : Signal Library.FolderResponse


libraryResponseActions : Signal Action
libraryResponseActions =
  let
      translate response =
        -- log ("Translate " ++ toString(response.folder))

        Library (Library.Response response.folder)
  in
      Signal.map translate libraryResponse


volumeChangeRequestsBox : Signal.Mailbox ( String, String, Float )
volumeChangeRequestsBox =
  Signal.mailbox ( "", "", 0.0 )


port volumeChangeRequests : Signal ( String, String, Float )
port volumeChangeRequests =
  volumeChangeRequestsBox.signal


zonePlayPauseRequestsBox : Signal.Mailbox ( String, Bool )
zonePlayPauseRequestsBox =
  Signal.mailbox ( "", False )


port playPauseChanges : Signal ( String, Bool )
port playPauseChanges =
  zonePlayPauseRequestsBox.signal


playlistSkipRequestsBox : Signal.Mailbox ( String, String )
playlistSkipRequestsBox =
  Signal.mailbox ( "", "" )


port playlistSkipRequests : Signal ( String, String )
port playlistSkipRequests =
  playlistSkipRequestsBox.signal


attachReceiverRequestsBox : Signal.Mailbox ( String, String )
attachReceiverRequestsBox =
  Signal.mailbox ( "", "" )


port attachReceiverRequests : Signal ( String, String )
port attachReceiverRequests =
  attachReceiverRequestsBox.signal


port libraryRequests : Signal String
port libraryRequests =
  let
      mailbox = Library.libraryRequestsBox
  in
      mailbox.signal
