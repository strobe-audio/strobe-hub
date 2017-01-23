module Library.View exposing (..)

import Html exposing (..)
import Html.Lazy
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import Animation
import Library
import Library.State
import List.Extra
import String
import Debug
import Utils.Css
import Utils.Text
import Utils.Touch exposing (onSingleTouch)
import Stack


root : Library.Model -> Html Library.Msg
root model =
    div [ class "library" ]
        [ (breadcrumb model)
        , (Html.Lazy.lazy levels model)
        ]


levels : Library.Model -> Html Library.Msg
levels model =
    let
        levels =
            Stack.toList model.levels
                |> (Maybe.map (\l -> [ l ]) model.unloadingLevel
                        |> Maybe.withDefault []
                        |> List.append
                   )
                |> List.reverse

        levelColumn ( l, isCurrent ) =
            case l.contents of
                Nothing ->
                    div
                        [ class "library--folder library--folder__loading" ]
                        [ div
                            [ class "library--spinner" ]
                            [ i [ class "fa fa-circle-o-notch fa-spin" ] []
                            , text "Loading..."
                            ]
                        ]

                Just folder_ ->
                    (Html.Lazy.lazy2 (folder model) folder_ isCurrent)

        count =
            (List.length levels) - 1

        columns =
            List.map levelColumn <| List.indexedMap (\p l -> (l, p == count)) levels

        left =
            case model.animationTime of
                Nothing ->
                    0

                Just time ->
                    -(Animation.animate time model.levelAnimation)
    in
        div
            [ class "library--levels", style [ ( "left", (toString left) ++ "vw" ) ] ]
            columns


folder : Library.Model -> Library.Folder -> Bool -> Html Library.Msg
folder model folder isCurrent =
    let
        children =
            if List.isEmpty folder.children then
                div [] []
            else
                div [ class "library-contents" ] (List.map (node model folder) folder.children)

        attrs =
            if isCurrent then
                [ id "__scrolling__" ]
            else
                [ ]
    in
        div ( attrs ++ [ class "library--folder" ])
            [ children ]


metadata : Library.Node -> Maybe (List Library.Metadata) -> Html Library.Msg
metadata node metadata =
    case metadata of
        Nothing ->
            div [] []

        Just metadataGroups ->
            div [ class "library--node--metadata" ] (List.map (metadataGroup node) metadataGroups)


metadataClick : String -> Library.Action -> List (Html.Attribute Library.Msg)
metadataClick title action =
    let
        options =
            { preventDefault = True, stopPropagation = True }
    in
        [ onWithOptions "click" options (Json.succeed (Library.ExecuteAction action title))
        , onSingleTouch (Library.ExecuteAction action title)
        ]


metadataGroup : Library.Node -> Library.Metadata -> Html Library.Msg
metadataGroup node group =
    let
        makeLink link =
            let
                attrs =
                    case link.action of
                        Nothing ->
                            [ class "library--no-action" ]

                        Just action ->
                            ([ class "library--click-action" ] ++ (metadataClick node.title action))
            in
                (a attrs [ text link.title ])

        links =
            List.map makeLink group
    in
        div [ class "library--node--metadata-group" ] links


node : Library.Model -> Library.Folder -> Library.Node -> Html Library.Msg
node library folder node =
    let
        isActive =
            Maybe.withDefault False
                (Maybe.map (\action -> node.actions.click.url == action) library.currentRequest)

        options =
            { preventDefault = True, stopPropagation = True }

        click msg =
            onWithOptions "click" options (Json.succeed msg)

        mapTouch a =
            Html.Attributes.map Library.Touch a
    in
        div
            [ classList
                [ ( "library--node", True )
                , ( "library--node__active", isActive )
                , ( "library--click-action", True )
                ]
            , onClick (Library.ExecuteAction node.actions.click node.title)
            , mapTouch (Utils.Touch.touchStart (Library.ExecuteAction node.actions.click node.title))
            , mapTouch (Utils.Touch.touchEnd (Library.ExecuteAction node.actions.click node.title))
            ]
            [ div
                [ class "library--node--icon"
                , style [ ( "backgroundImage", (Utils.Css.url node.icon) ) ]
                , click (Library.MaybeExecuteAction node.actions.play node.title)
                , mapTouch (Utils.Touch.touchStart (Library.MaybeExecuteAction node.actions.play node.title))
                , mapTouch (Utils.Touch.touchEnd (Library.MaybeExecuteAction node.actions.play node.title))
                ]
                []
            , div [ class "library--node--inner" ]
                [ div []
                    [ text (Utils.Text.truncateEllipsis node.title 90) ]
                , (metadata node node.metadata)
                ]
            ]


breadcrumb : Library.Model -> Html Library.Msg
breadcrumb model =
    let
        breadcrumbLink classes index level =
            a
                [ class classes
                , onClick (Library.PopLevel (index))
                , onSingleTouch (Library.PopLevel (index))
                ]
                [ text level.title ]

        sections =
            (Stack.toList model.levels)
                |> List.indexedMap (breadcrumbLink "library--breadcrumb--section")

        ( list_, dropdown_ ) =
            List.Extra.splitAt 1 (sections)

        dividers list =
            List.intersperse (span [ class "library--breadcrumb--divider" ] []) list

        dropdown =
            dividers (List.reverse dropdown_)

        list =
            dividers (List.reverse list_)

        dropdownEmpty =
            if List.isEmpty dropdown_ then
                True
            else
                False
    in
        div [ class "library--breadcrumb" ]
            [ div [ classList [ ( "library--breadcrumb--dropdown", True ), ( "library--breadcrumb--dropdown__empty", dropdownEmpty ) ] ] dropdown
              -- , span [ class "library--breadcrumb--divider" ] []
            , div [ class "library--breadcrumb--sections" ] list
            ]
