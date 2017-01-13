module Utils.Touch exposing (..)

import Time exposing (Time)
import Html
import Html.Events
import Touch -- exposing (TouchEvent(..))
import SingleTouch exposing (SingleTouch)
import MultiTouch exposing (MultiTouch, onMultiTouch)
import Json.Decode as Decode

type E msg
    = Start T
    | End T msg

type alias T =
  { clientX : Float
  , clientY : Float
  , time : Int
  }

type alias Model =
  { start : T
  , end : T
  }

emptyT : T
emptyT =
  { clientX = 0.0 , clientY = 0.0 , time = 0 }

emptyModel : Model
emptyModel =
  { start = emptyT, end = emptyT }

update : E msg -> Model -> Model
update event model =
  case event of
      Start t ->
          touchStart model t

      End t m ->
          touchEnd model t

onSingleTouch : msg -> Html.Attribute msg
onSingleTouch msg =
  SingleTouch.onSingleTouch Touch.TouchStart preventAndStop <| (always msg)

onUnifiedClick : msg -> List (Html.Attribute msg)
onUnifiedClick msg =
  [ SingleTouch.onSingleTouch Touch.TouchStart preventAndStop <| (always msg)
  , Html.Events.onClick msg
  ]


-- onSingleTouchWithoutScroll : (msg E) -> msg -> List (Html.Attribute (E msg))
-- onSingleTouchWithoutScroll ns msg =
--     [ Html.Events.onWithOptions
--         "touchstart"
--         preventAndStop
--         (Decode.map3
--             (\x y t -> ns (Start { clientX = x, clientY = y, time = t }))
--             (Decode.at ["touches", "0", "clientX"] Decode.float)
--             (Decode.at ["touches", "0", "clientY"] Decode.float)
--             (Decode.field "timeStamp" Decode.int)
--         )
--     , Html.Events.onWithOptions
--         "touchend"
--         preventAndStop
--         (Decode.map3
--             (\x y t -> ns (End { clientX = x, clientY = y, time = t } msg))
--             (Decode.at ["touches", "0", "clientX"] Decode.float)
--             (Decode.at ["touches", "0", "clientY"] Decode.float)
--             (Decode.field "timeStamp" Decode.int)
--         )
--       -- (\mt ->
--       --   let
--       --       _ = Debug.log "multi end" mt
--       --   in
--       --       Start { clientX = mt.clientX, clientY = mt.clientY, time =  }
--       --   )
--     ]

preventAndStop : Html.Events.Options
preventAndStop =
    { stopPropagation = True
    , preventDefault = True
    }

touchStart : Model -> T -> Model
touchStart model t =
  { model | start = t }

touchEnd : Model -> T -> Model
touchEnd model t =
  { model | end = t }

singleClickDuration = 500
singleClickDistance = 40

isSingleClick : E msg -> Model -> Maybe msg
isSingleClick event model =
  case event of
      Start t ->
          Nothing

      End t m ->
          let
              dx = model.end.clientX - model.start.clientX
              dy = model.end.clientY - model.start.clientY
              dd = Debug.log "dd" (sqrt  (dx * dx) + (dy * dy) )
              tt = Debug.log "tt" (model.end.time - model.start.time)
          in
            if (dd <= singleClickDistance) && (tt <= singleClickDuration) then
                Debug.log "single click event" (Just m)

            else
                Nothing
