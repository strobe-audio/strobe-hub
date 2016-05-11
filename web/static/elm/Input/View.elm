module Input.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import Input


inputSubmitCancel : Input.Context -> Input.Model -> Html
inputSubmitCancel context model =
  let
    valid =
      model.validator model.value
  in
    div
      [ class "input" ]
      [ input
          [ class "input--input"
          , type' "text"
          , placeholder "Channel name..."
          , value model.value
          , on "input" targetValue (Signal.message context.address << Input.Update)
          , onKeyDown context.address (Input.Submit context) (Input.Cancel context)
          , autofocus True
          , attribute "autocapitalize" "words"
          ]
          []
      , div
          [ classList [ ( "input--submit", True ), ( "input--submit__valid", valid ) ]
          , onClick context.address (Input.Submit context)
          ]
          []
      , div [ class "input--cancel", onClick context.address (Input.Cancel context) ] []
      ]


onKeyDown : Signal.Address Input.Action -> Input.Action -> Input.Action -> Attribute
onKeyDown address submitAction cancelAction =
  on
    "keydown"
    (Json.customDecoder keyCode (submitOrCancel submitAction cancelAction))
    (\action -> Signal.message address action)


submitOrCancel : Input.Action -> Input.Action -> Int -> Result String Input.Action
submitOrCancel submitAction cancelAction code =
  case code of
    13 ->
      Ok submitAction

    27 ->
      Ok cancelAction

    _ ->
      Err "ignored key code"
