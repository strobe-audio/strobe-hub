module Main where

import Html exposing (..)
import Html.Attributes exposing (..)
import StartApp
import Effects exposing (Effects, Never)
import Task exposing (Task)
import Debug

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

type Action
  = InitialState Model
  | ReceiverStatus (String, ReceiverStatusEvent)

init : (Model, Effects Action)
init =
  let
    model = { zones = [], receivers = [] }
  in
    (model, Effects.none)

receiverOnline : List Receiver -> String -> Bool -> List Receiver
receiverOnline receivers receiverId online =
  List.map (\r ->
    if r.id == receiverId then
     { r | online = online }
    else
      r
  ) receivers

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    InitialState state ->
      (state, Effects.none)
    ReceiverStatus (event, args) ->
      case event of
        "receiver_added" ->
          let
              model = { model | receivers = (receiverOnline model.receivers args.receiverId True)}
          in
            (model, Effects.none)
        "receiver_removed" ->
          let
              model = { model | receivers = (receiverOnline model.receivers args.receiverId False)}
          in
            (model, Effects.none)
        _ ->
          (model, Effects.none)

zoneReceivers : Model -> Zone -> List Receiver
zoneReceivers model zone =
  List.filter (\r -> r.zoneId == zone.id) model.receivers

receiverInZone : Receiver -> Html
receiverInZone receiver =
  div [ classList [("receiver", True), ("receiver--online", receiver.online), ("receiver--offline", not receiver.online)] ] [ text receiver.name ]

zone : Model -> Signal.Address Action -> Zone -> Html
zone model action zone =
  div [ class "zone four wide column" ] [
    div [ class "ui card" ] [
      div [ class "content" ] [
        div [ class "header" ] [ text zone.name ]
      ],
      div [ class "content" ] (List.map receiverInZone (zoneReceivers model zone))
    ]
  ]

view : Signal.Address Action -> Model -> Html
view address model =
  div [ class "ui container" ] [
    div [ class "zones ui grid" ] (List.map (zone model address) model.zones)
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

port initialState : Signal Model

port receiverStatus : Signal (String, ReceiverStatusEvent)

