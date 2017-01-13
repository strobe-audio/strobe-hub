module Utils.Touch exposing (..)

import Time exposing (Time)
import Html
import Html.Events
import Touch


-- exposing (TouchEvent(..))

import SingleTouch exposing (SingleTouch)
import MultiTouch exposing (MultiTouch, onMultiTouch)
import Json.Decode as Decode

-- Only support left/right swipes (who swipes *up*!??)

type Direction
    = Left
    | Right


type Gesture
    = None
    | Tap
    | LongPress
    | Swipe Direction Float

type alias SwipeModel =
    { offset : Float
    }

type E msg
    = Start T msg
    | Actual T msg
    | End T msg


type alias T =
    { clientX : Float
    , clientY : Float
    , time : Int
    }


type alias Model =
    { start : Maybe T
    , actual : Maybe T
    , end : Maybe T
    }


emptyModel : Model
emptyModel =
    { start = Nothing
    , actual = Nothing
    , end = Nothing
    }


update : E msg -> Model -> Model
update event model =
    case event of
        Start t m ->
            { model | start = Just t, actual = Nothing, end = Nothing }

        Actual t m ->
            { model | actual = Just t, end = Nothing }

        End t m ->
            { model | end = Just t }


onSingleTouch : msg -> Html.Attribute msg
onSingleTouch msg =
    SingleTouch.onSingleTouch Touch.TouchStart preventAndStop <| (always msg)


onUnifiedClick : msg -> List (Html.Attribute msg)
onUnifiedClick msg =
    [ SingleTouch.onSingleTouch Touch.TouchStart preventAndStop <| (always msg)
    , Html.Events.onClick msg
    ]


preventAndStop : Html.Events.Options
preventAndStop =
    { stopPropagation = True
    , preventDefault = True
    }


singleClickDuration =
    500


singleClickDistance =
    40


decodeTouchEvent : String -> (T -> E msg) -> Decode.Decoder (E msg)
decodeTouchEvent key map =
    (Decode.map3
        (\x y t -> (map { clientX = x, clientY = y, time = t }))
        (Decode.at [ key, "0", "clientX" ] Decode.float)
        (Decode.at [ key, "0", "clientY" ] Decode.float)
        (Decode.field "timeStamp" Decode.int)
    )


touchStart : msg -> Html.Attribute (E msg)
touchStart msg =
    Html.Events.onWithOptions
        "touchstart"
        { stopPropagation = False, preventDefault = False }
        (decodeTouchEvent "touches" (\t -> (Start t msg)))


touchMove : msg -> Html.Attribute (E msg)
touchMove msg =
    Html.Events.onWithOptions
        "touchmove"
        { stopPropagation = False, preventDefault = False }
        (decodeTouchEvent "changedTouches" (\t -> (Actual t msg)))


touchEnd : msg -> Html.Attribute (E msg)
touchEnd msg =
    Html.Events.onWithOptions
        "touchend"
        preventAndStop
        (decodeTouchEvent "changedTouches" (\t -> (End t msg)))


isSingleClick : E msg -> Model -> Maybe msg
isSingleClick event model =
    case event of
        Start t m ->
            Nothing

        -- this could return e.g. long-click or slide events
        Actual t m ->
            Nothing

        End t m ->
            (Maybe.map2 (testSingleClick m) model.start model.end) |> Maybe.andThen (\x -> x)


testSingleClick : msg -> T -> T -> Maybe msg
testSingleClick msg start end =
    let
        dx =
            end.clientX - start.clientX

        dy =
            end.clientY - start.clientY

        dd =
            (sqrt (dx * dx) + (dy * dy))

        tt =
            (end.time - start.time)
    in
        if (dd <= singleClickDistance) && (tt <= singleClickDuration) then
            Debug.log "single click event" (Just msg)
        else
            Nothing


testEvent : E msg -> Model -> Gesture
testEvent event model =
    case event of
        Start touch msg ->
            None

        -- this could return e.g. long-click or swipe events
        Actual touch msg ->
          case model.start of
            Just start ->
              let
                  min =
                      50
                  dx =
                      (touch.clientX - start.clientX)

                  off =
                      abs dx

                  dy =
                      touch.clientY - start.clientY |> abs
              in
                  if (off >= min) && (dy < min) then
                      (Swipe (directionOf dx) off)
                  else
                      None


            Nothing ->
              None


        End touch msg ->
            None
            -- (Maybe.map2 (testSingleClick m) model.start model.end) |> Maybe.andThen (\x -> x)


directionOf : Float -> Direction
directionOf dx =
    if dx < 0 then
        Left
    else
        Right
