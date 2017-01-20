module Notification.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Notification
import Msg exposing (Msg)
import Time exposing (Time)


notifications : Maybe Time -> List (Notification.Model msg) -> Html msg
notifications maybeTime nn =
    case maybeTime of
        Nothing ->
            div [] []

        Just t ->
            div
                [ class "notification--list" ]
                (List.map (notification t) nn)


notification : Time -> Notification.Model msg -> Html msg
notification t n =
    let
        opacity =
            Notification.animate t n |> toString
    in
        div [ class "notification", style [ ( "opacity", opacity ) ] ] [ n.title ]
