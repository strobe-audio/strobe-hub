module Receivers (viewAttached) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Effects exposing (Effects, Never)
import Types exposing (..)
import Volume


viewAttached : Signal.Address Action -> Receiver -> Html
viewAttached address receiver =
  div
    [ classList
        [ ( "receiver", True )
        , ( "receiver--online", receiver.online )
        , ( "receiver--offline", not receiver.online )
        ]
    ]
    [ Volume.volumeControl address receiver.volume receiver.name (UpdateReceiverVolume receiver) ]



-- viewDetached : Signal.Address Action  -> Receiver -> Html
-- viewDetached address channel receivers =
--   div [ class "channel-receivers--available" ] (List.map (\r ->
--     div [ class "channel-receivers--available-receiver" ] [
--       div [ class "channel-receivers--add-receiver", onClick address ( AttachReceiver channel r ) ] [
--         text r.name
--       ]
--     , div [ class "channel-receivers--edit-receiver" ] [
--         i [ class "fa fa-pencil" ] []
--       ]
--     ]
--   ) receivers)
