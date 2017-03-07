module Notification exposing (..)

import Html
import Animation exposing (Animation)
import Ease
import Time exposing (Time)
import Rendition


type alias Model msg =
    { id : String
    , title : Html.Html msg
    , addedTime : Time
    , appearAnimation : Animation
    , disappearAnimation : Animation
    }


animate : Time -> Model msg -> Float
animate t n =
    (Animation.animate t n.appearAnimation)
        * (Animation.animate t n.disappearAnimation)


isVisible : Time -> Model msg -> Bool
isVisible t n =
    (not <| (Animation.isDone t n.appearAnimation))
        || (not <| (Animation.isDone t n.disappearAnimation))


appearAnimation : Time -> Animation.Animation
appearAnimation time =
    (Animation.animation time)
        |> (Animation.from 0.0)
        |> Animation.to 1.0
        |> Animation.duration (300 * Time.millisecond)
        |> Animation.ease Ease.inOutSine


disappearAnimation : Time -> Animation.Animation
disappearAnimation time =
    (Animation.animation time)
        |> Animation.delay (1 * Time.second)
        |> Animation.from 1.0
        |> Animation.to 0.0
        |> Animation.duration (300 * Time.millisecond)
        |> Animation.ease Ease.inOutSine


forRendition : Time -> Rendition.State -> Model msg
forRendition time rendition =
    { id = rendition.id
    , title = renditionNotificationTitle rendition
    , addedTime = time
    , appearAnimation = appearAnimation time
    , disappearAnimation = disappearAnimation time
    }


renditionNotificationTitle : Rendition.State -> Html.Html msg
renditionNotificationTitle rendition =
    Html.div
        []
        [ Html.text "Added "
        , Html.strong [] [ Html.text (Maybe.withDefault "Untitled Track" rendition.source.title) ]
        , Html.text " to playlist"
        ]
