module Library.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
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
        , (levels model)
        ]

levels : Library.Model -> Html Library.Msg
levels model =
    let
        levels =
            Stack.toList model.levels |> List.reverse

        levelColumn l =
            case l.contents of
                Nothing ->
                    div [] [ text "Not loaded" ]
                Just folder_ ->
                    folder model folder_

        columns =
            List.map levelColumn levels

        left =
            model.depth * -100

    in
        div
            [ class "library--levels", style [("left", (toString left) ++ "vw")] ]
            columns


folder : Library.Model -> Library.Folder -> Html Library.Msg
folder model folder =
    let
        children =
            if List.isEmpty folder.children then
                div [] []
            else
                div [ class "library-contents" ] (List.map (node model folder) folder.children)
    in
        div [ class "library--folder" ]
            [ children ]


metadata : Maybe (List Library.Metadata) -> Html Library.Msg
metadata metadata =
    case metadata of
        Nothing ->
            div [] []

        Just metadataGroups ->
            div [ class "library--node--metadata" ] (List.map (metadataGroup) metadataGroups)


metadataClick : String -> List (Html.Attribute Library.Msg)
metadataClick action =
    let
        options =
            { preventDefault = True, stopPropagation = True }
    in
        [ onWithOptions "click" options (Json.succeed (Library.ExecuteAction action))
        , onSingleTouch (Library.ExecuteAction action)
        ]


metadataGroup : Library.Metadata -> Html Library.Msg
metadataGroup group =
    let
        makeLink link =
            let
                attrs =
                    case link.action of
                        Nothing ->
                            [ class "library--no-action" ]

                        Just action ->
                            ([ class "library--click-action" ] ++ (metadataClick action))
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
                (Maybe.map (\action -> node.actions.click == action) library.currentRequest)

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
            , onClick (Library.ExecuteAction node.actions.click)
            , mapTouch (Utils.Touch.touchStart (Library.ExecuteAction node.actions.click))
            , mapTouch (Utils.Touch.touchEnd (Library.ExecuteAction node.actions.click))
            ]
            [ div
                [ class "library--node--icon"
                , style [ ( "backgroundImage", (Utils.Css.url node.icon) ) ]
                , click (Library.MaybeExecuteAction node.actions.play)
                , mapTouch (Utils.Touch.touchStart (Library.MaybeExecuteAction node.actions.play))
                , mapTouch (Utils.Touch.touchEnd (Library.MaybeExecuteAction node.actions.play))
                ]
                []
            , div [ class "library--node--inner" ]
                [ div []
                    [ text (Utils.Text.truncateEllipsis node.title 90) ]
                , (metadata node.metadata)
                ]
            ]




breadcrumb : Library.Model -> Html Library.Msg
breadcrumb model =
    let
        breadcrumbLink classes index level =
            let
                title = Maybe.map (\f -> f.title) level.contents |> Maybe.withDefault "Not loaded"
            in
                a
                    [ class classes
                    , onClick (Library.PopLevel (index))
                    , onSingleTouch (Library.PopLevel (index))
                    ]
                    [ text title ]

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
