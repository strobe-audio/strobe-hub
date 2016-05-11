module Library.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Library
import Library.State
import List.Extra


root : Signal.Address Library.Action -> Library.Model -> Html
root address model =
  div
    [ class "library" ]
    [ folder address model (Library.State.currentLevel model) ]


node : Signal.Address Library.Action -> Library.Model -> Library.Folder -> Library.Node -> Html
node address library folder node =
  let
    isActive =
      Maybe.withDefault
        False
        (Maybe.map (\action -> node.action == action) library.currentRequest)
  in
    div
      [ classList
          [ ( "library--node", True )
          , ( "library--node__active", isActive )
          ]
      , onClick address (Library.ExecuteAction node.action)
      ]
      [ div
          [ class "library--node--inner" ]
          [ text node.title ]
      ]


folder : Signal.Address Library.Action -> Library.Model -> Library.Folder -> Html
folder address model folder =
  let
    children =
      if List.isEmpty folder.children then
        div [] []
      else
        div [ class "block-group library-contents" ] (List.map (node address model folder) folder.children)
  in
    -- Debug.log (" folder " ++ (toString folder))
    div
      []
      [ (breadcrumb address model folder)
      , children
      ]


breadcrumb : Signal.Address Library.Action -> Library.Model -> Library.Folder -> Html
breadcrumb address model folder =
  let
    breadcrumbLink classes index level =
      a [ class classes, onClick address (Library.PopLevel (index)) ] [ text level.title ]

    sections =
      (model.levels)
        |> List.indexedMap (breadcrumbLink "library--breadcrumb--section")

    ( list', dropdown' ) =
      List.Extra.splitAt 2 (sections)

    dividers list =
      List.intersperse (span [ class "library--breadcrumb--divider" ] []) list

    dropdown =
      dividers (List.reverse dropdown')

    list =
      dividers (List.reverse list')
  in
    div
      [ class "library--breadcrumb" ]
      [ div [ class "library--breadcrumb--dropdown" ] dropdown
        -- , span [ class "library--breadcrumb--divider" ] []
      , div [ class "library--breadcrumb--sections" ] list
      ]
