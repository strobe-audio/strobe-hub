module Input.State exposing (..)

import Debug
import Input


blank : Input.Model
blank =
    { originalValue = ""
    , value = ""
    , validator = notBlankValidator
    , autoCapitalize = "words"
    }


withValue : Input.Model -> String -> Input.Model
withValue input value =
    { input
        | originalValue = value
        , value = value
    }


clear : Input.Model -> Input.Model
clear input =
    { input
        | originalValue = ""
        , value = ""
    }


notBlankValidator : String -> Bool
notBlankValidator value =
    value /= ""


update : Input.Msg -> Input.Model -> ( Input.Model, Cmd Input.Msg, Maybe Input.Signal )
update action model =
    case action of
        Input.Update value ->
            ( { model | value = value }, Cmd.none, Nothing )

        Input.Cancel ->
            ( model, Cmd.none, Just Input.Close )

        Input.Submit ->
            let
                valid =
                    model.validator model.value

                effect =
                    case valid of
                        True ->
                            Just (Input.Value model.value)

                        False ->
                            Nothing
            in
                ( model, Cmd.none, effect )

        _ ->
            ( model, Cmd.none, Nothing )
