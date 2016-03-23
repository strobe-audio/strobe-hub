
module Main where

import Html exposing (..)
import StartApp
import Effects exposing (Effects, Never)
import Task exposing (Task)

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

type Action
  = InitialState Model

init : (Model, Effects Action)
init =
  let
    model = { zones = [], receivers = [] }
  in
    (model, Effects.none)

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    InitialState state ->
      (state, Effects.none)

zone : Signal.Address Action -> Zone -> Html
zone action zone =
  div [] [ text zone.name ]

view : Signal.Address Action -> Model -> Html
view address model =
  div [] (List.map (zone address) model.zones)
  -- Html.text "Hello"

incomingActions : Signal Action
incomingActions =
  Signal.map InitialState initialState

app =
  StartApp.start
    { init = init
    , update = update
    , view = view
    , inputs = [incomingActions]
    }

main : Signal Html
main =
  app.html

port initialState : Signal Model
-- port tasks =
--   app.tasks
