module Utils.Touch exposing (..)

import Time exposing (Time)
import Html
import Html.Events
import Touch


-- exposing (TouchEvent(..))

import SingleTouch exposing (SingleTouch)
import MultiTouch exposing (MultiTouch, onMultiTouch)
import Json.Decode as Decode
import Animation exposing (Animation)


-- Only support left/right swipes (who swipes *up*!??)

type Axis
    = X
    | Y

type Direction
    = Left
    | Right
    | Up
    | Down


type Gesture msg
    = Touch msg
    | Tap msg
    | LongPress msg
    | Swipe Axis Direction Float Float msg
    | Flick (Time -> Float -> Maybe Momentum -> Momentum) msg


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
    , actual : List T
    , end : Maybe T
    , savedMomentum : Maybe Momentum
    }

type alias Momentum =
    { time : Time
    , startTime : Time
    , lifeTime : Time
    , speed : Float
    , position : Float
    }

type ScrollState
    = Scrolling Momentum
    | ScrollComplete Float


null : Model
null =
    emptyModel


emptyModel : Model
emptyModel =
    { start = Nothing
    , actual = []
    , end = Nothing
    , savedMomentum = Nothing
    }


update : E msg -> Model -> Model
update event model =
    case event of
        Start t m ->
            { model | start = Just t, actual = [], end = Nothing }

        Actual t m ->
            let
                actual =
                    (t :: model.actual) |> List.take 4

            in
                { model | actual = actual, end = Nothing }

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
    400


singleClickDistance =
    10


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
            Debug.log "tap distance" (sqrt ((dx * dx) + (dy * dy)))

        tt =
            Debug.log "tap duration" (end.time - start.time)
    in
        if (dd <= singleClickDistance) && (tt <= singleClickDuration) then
            Debug.log "single click event" (Just msg)
        else
            Nothing


-- TODO: don't need last event here, the model should have been updated
-- before calling this, so we can just test for existance of end & actual
-- (in that order)
testEvent : E msg -> Model -> Maybe (Gesture msg)
testEvent event model =
    case event of
        Start touch msg ->
            Just (Touch msg)

        -- this could return e.g. long-click or swipe events
        Actual touch msg ->
            (testStartActualEvent model)
                |> Maybe.map (\g -> (g msg))

        End touch msg ->
             model.start
                 |> Maybe.andThen (testStartEndEvent model touch)
                 |> Maybe.map (\g -> (g msg))


testStartActualEvent : Model -> Maybe (msg -> Gesture msg)
testStartActualEvent model =
    case model.start of
        -- unlikely..
        Nothing ->
            Nothing

        Just start ->
            let
                ( dx, dy ) =
                    case model.actual of
                        a :: b :: _ ->
                            ( a.clientX - b.clientX, a.clientY - b.clientY )

                        a :: _ ->
                            ( a.clientX - start.clientX, a.clientY - start.clientY )

                        [] ->
                            ( 0, 0 )

                ( offx, offy ) =
                    ( abs dx, abs dy )

                ( mx, my ) =
                    (case model.actual of
                        a :: _ ->
                            ( a.clientX - start.clientX, a.clientY - start.clientY )
                        [] ->
                            ( 0, 0 )
                    )

            in
                if offx > offy then
                    Just (Swipe X (xDirectionOf dx) dx mx)

                else
                    if offy > offx then
                        Just (Swipe Y (yDirectionOf dy) dy my)
                    else
                        Nothing


testStartEndEvent : Model -> T -> T -> Maybe (msg -> Gesture msg)
testStartEndEvent model end start =
    let
        min =
            50

        tx =
            end.clientX - start.clientX

        ty =
            end.clientY - start.clientY

        dd =
            (sqrt (tx * tx) + (ty * ty))

        tt =
            (end.time - start.time)

        ( fy, ft ) =
            case model.actual of
                _ :: last :: _ ->
                    ( end.clientY - last.clientY
                    , toFloat <| (end.time - last.time)
                    )

                _ ->
                    (0.0, 0.0)

    in
        if (dd <= singleClickDistance) && (tt <= singleClickDuration) then
            Just Tap

        else
            if (fy /= 0) && ((abs fy) > 10) then
                Just
                    (Flick
                        (\t p m ->
                            let
                                speed =
                                    case m of
                                        Nothing ->
                                            (flickSpeed fy ft)

                                        Just momentum ->
                                            (momentum.speed + (flickSpeed fy ft))
                            in
                                { time = t
                                , startTime = t
                                , lifeTime = 3000.0
                                , speed = speed
                                , position = p
                                }
                        )
                    )
            else
                Nothing


xDirectionOf : Float -> Direction
xDirectionOf dx =
    if dx < 0 then
        Left
    else
        Right


yDirectionOf : Float -> Direction
yDirectionOf dy =
    if dy < 0 then
        Up
    else
        Down


flickSpeed : Float -> Float -> Float
flickSpeed dy dt =
    dy / dt


scrollFriction : Float -> Float
scrollFriction age =
    (1.0 + (0.1 * age))


scrollPosition : Time -> Momentum -> Float -> Float -> ScrollState
scrollPosition time momentum length height =
    let
        dt =
            time - momentum.time

        age =
            ((time - momentum.startTime) / momentum.lifeTime) |> (min 1.0)

        speed =
            momentum.speed / (scrollFriction age)

        dp =
            dt * speed

        p =
            momentum.position + dp

        end =
            -(length - (height * 0.6))
    in
        if (abs speed) <= 0.02 then
            ScrollComplete p
        else
            if p > 0 then
                ScrollComplete 0.0
            else
                if p <= end then
                    ScrollComplete end
                else
                    Scrolling { momentum | position = p, time = time, speed = speed }


slowScroll : Maybe Momentum -> Bool
slowScroll maybeMomentum =
    case maybeMomentum of
        Nothing ->
            True

        -- loading any images disrupts the scroll
        Just momentum ->
            -- (abs momentum.speed) < 0.20
            False
