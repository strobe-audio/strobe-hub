module Library.View (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import Library
import Library.State
import List.Extra
import String
import Debug


root : Signal.Address Library.Action -> Library.Model -> Html
root address model =
  div
    [ class "library" ]
    [ folder address model (Library.State.currentLevel model) ]

url : String -> String
url path =
  String.concat ["url(\"", path, "\")"]

metadata : Signal.Address Library.Action -> Maybe (List Library.Metadata) -> Html
metadata address metadata =
  case metadata of
    Nothing ->
      div [] []

    Just metadataGroups ->
      div [ class "library--node--metadata" ] (List.map (metadataGroup address) metadataGroups)


metadataClick : Signal.Address Library.Action -> String -> Html.Attribute
metadataClick address action =
  let
      options =
        { preventDefault = True, stopPropagation = True }
  in
      onWithOptions "click" options Json.value (\_ -> Signal.message address (Library.ExecuteAction action) )

metadataGroup : Signal.Address Library.Action -> Library.Metadata -> Html
metadataGroup address group =
  let
      makeLink link =
        let
            attrs = case link.action of
              Nothing ->
                [ class "library--no-action" ]
              Just action ->
                [ class "library--click-action", (metadataClick address action) ]
        in
            (a attrs [ text link.title ])
      links =
        List.map makeLink group
  in
      div [ class "library--node--metadata-group" ] links


node : Signal.Address Library.Action -> Library.Model -> Library.Folder -> Library.Node -> Html
node address library folder node =
  let
    isActive =
      Maybe.withDefault
        False
        (Maybe.map (\action -> node.actions.click == action) library.currentRequest)
  in
    div
      [ classList
          [ ( "library--node", True )
          , ( "library--node__active", isActive )
          , ( "library--click-action", True )
          ]
      , onClick address (Library.ExecuteAction node.actions.click)
      ]
      [ div
          [ class "library--node--icon", style [("backgroundImage", (url node.icon))] ]
          []
      , div
          [ class "library--node--inner" ]
          [ div
            []
            [ a [] [text node.title] ]
          , (metadata address node.metadata)
          ]
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
