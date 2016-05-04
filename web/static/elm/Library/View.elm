module Library.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Library
import Library.State


root : Signal.Address Library.Action -> Library.Model -> Html
root address model =
  folder address model (Library.State.currentLevel model)


node : Signal.Address Library.Action -> Library.Model -> Library.Folder -> Library.Node -> Html
node address library folder node =
  div [ class "block", onClick address (Library.ExecuteAction node.action) ] [ text node.title ]


breadcrumb : Signal.Address Library.Action -> Library.Model -> Library.Folder -> Html
breadcrumb address model folder =
  let
    breadcrumbLink classes index level =
      -- Debug.log ("level " ++ level.action)
      a [ class classes, onClick address (Library.PopLevel (index + 1)) ] [ text level.title ]

    sections =
      case List.tail model.levels of
        Just levels ->
          List.indexedMap (breadcrumbLink "section") levels

        Nothing ->
          []

    levels =
      (div [ class "section active" ] [ text folder.title ]) :: sections

    breadcrumb =
      List.intersperse (i [ class "right angle icon divider" ] []) levels
  in
    div [ class "ui breadcrumb" ] (List.reverse breadcrumb)


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
      [ div
          [ class "block-group library-folder" ]
          [ div
              [ class "library-breadcrumb" ]
              [ (breadcrumb address model folder)
              ]
          ]
      , children
      ]
