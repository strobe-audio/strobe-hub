module Input.State (..) where

import Effects exposing (Effects, Never)
import Debug
import Input


blank : Input.Model
blank =
  { originalValue = ""
  , value = ""
  , validator = (\s -> s /= "")
  }


update : Input.Action -> Input.Model -> ( Input.Model, Effects Input.Action )
update action model =
  case action of
    Input.Update value ->
      ( { model | value = value }, Effects.none )

    Input.Cancel context ->
      ( model, sendCancel context )

    Input.Submit context ->
      let
        valid =
          model.validator model.value

        effect =
          case valid of
            True ->
              sendSubmit context model.value

            False ->
              Effects.none
      in
        ( model, effect )

    _ ->
      ( model, Effects.none )


sendCancel : Input.Context -> Effects Input.Action
sendCancel context =
  Signal.send context.cancelAddress ()
    |> Effects.task
    |> Effects.map (always Input.NoOp)


sendSubmit : Input.Context -> String -> Effects Input.Action
sendSubmit context value =
  Signal.send context.submitAddress value
    |> Effects.task
    |> Effects.map (always Input.NoOp)
