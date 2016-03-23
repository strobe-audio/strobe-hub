module Main where

import String
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import StartApp
import Effects exposing (Effects, Never)
import Task exposing (Task)
import Debug

-- volume sliders go from 0 - this value so we have to convert to a 0-1 range
-- before setting the volume
volumeRangeMax = 1000

type alias Zone =
  { id:       String
  , name:     String
  , position: Int
  , volume:   Float
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
  }

type BroadcasterEventArg = String | Float | Int

type alias ReceiverStatusEvent =
  { event:      String
  , zoneId:     String
  , receiverId: String
  }

init : (Model, Effects Action)
init =
  let
    model = { zones = [], receivers = [] }
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


type Action
  = InitialState Model
  | ReceiverStatus (String, ReceiverStatusEvent)
  | UpdateReceiverVolume Receiver String
  | UpdateZoneVolume Zone String
  | NoOp


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


zoneReceivers : Signal.Address Action -> Model -> Zone -> List Receiver
zoneReceivers address model zone =
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


zonePanel : Signal.Address Action -> Model -> Zone -> Html
zonePanel address model zone =
  div [ class "zone five wide column" ] [
    div [ class "ui card" ] [
      div [ class "content" ] [
        div [ class "header" ] [
          text zone.name,
          volumeControl address zone.volume (UpdateZoneVolume zone)
        ]
      ],
      div [ class "content" ] (List.map (receiverInZone address) (zoneReceivers address model zone))
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

app =
  StartApp.start
    { init = init
    , update = update
    , view = view
    , inputs = [incomingActions, receiverStatusActions]
    }


main : Signal Html
main =
  app.html

port tasks : Signal (Task Never ())
port tasks =
  app.tasks

port initialState : Signal Model

port receiverStatus : Signal ( String, ReceiverStatusEvent )

port volumeChanges : Signal ( String, String, Float )
port volumeChanges =
  volumeChangeRequestsBox.signal

volumeChangeRequestsBox : Signal.Mailbox ( String, String, Float )
volumeChangeRequestsBox =
  Signal.mailbox ( "", "", 0.0 )
