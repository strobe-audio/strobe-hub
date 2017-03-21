module Settings.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Settings
import Msg exposing (Msg)


application : Maybe Settings.Model -> Html Msg
application maybeModel =
    case maybeModel of
        Nothing ->
            div [ class "settings-loading" ] [ text "loading..." ]

        Just model ->
            applicationSettings model


applicationSettings : Settings.Model -> Html Msg
applicationSettings model =
    div
        [ class "settings-container" ]
        [ div [ class "settings-namespaces" ] (List.map namespace model.namespaces)
        ]


namespace : Settings.NameSpace -> Html Msg
namespace ns =
    div
        [ class "settings-namespace" ]
        [ h2 [ class "settings-namespace__title" ] [ text ns.title ]
        , (fields ns.fields)
        ]


fields : Settings.Fields -> Html Msg
fields fields =
    div
        [ class "settings-fields" ]
        (List.map field fields)


field : Settings.Field -> Html Msg
field field =
    div
        [ class "settings-field" ]
        [ label [] [ text field.title ]
        , (fieldInput field)
        ]


fieldInput : Settings.Field -> Html Msg
fieldInput field =
    let
        change =
            onInput (Msg.UpdateApplicationSettings field)
    in
        case field.inputType of
            "password" ->
                input [ type_ "password", value field.value, name field.name, change ] []

            _ ->
                input [ type_ "text", value field.value, name field.name, change ] []
