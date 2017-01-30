module Library.View exposing (..)

import Html exposing (..)
import Html.Lazy exposing (lazy, lazy2)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed
import Json.Decode as Json
import Animation
import Library
import Library.State
import List.Extra
import String
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
            Stack.toList model.levels
                |> (Maybe.map (\l -> [ l ]) model.unloadingLevel
                        |> Maybe.withDefault []
                        |> List.append
                   )
                |> List.reverse

        levelColumn ( l, isCurrent ) =
            case l.contents of
                Nothing ->
                    ( l.action
                    , div
                        [ class "library--folder library--folder__loading" ]
                        [ div
                            [ class "library--spinner" ]
                            [ i [ class "fa fa-circle-o-notch fa-spin" ] []
                            , text "Loading..."
                            ]
                        ]
                    )

                Just folder_ ->
                    ( l.action
                    , (folder model folder_ isCurrent)
                    )

        count =
            (List.length levels) - 1

        columns =
            List.map levelColumn <| List.indexedMap (\p l -> ( l, p == count )) levels

        left =
            case model.animationTime of
                Nothing ->
                    0

                Just time ->
                    -(Animation.animate time model.levelAnimation)
    in
        Html.Keyed.node
            "div"
            [ class "library--levels", style [ ( "left", (toString left) ++ "vw" ) ] ]
            columns


folder : Library.Model -> Library.Folder -> Bool -> Html Library.Msg
folder model folder isCurrent =
    let
        childHeight =
            60.0

        ( childrenOffset, childrenCount ) =
            libraryChildrenViewOffset model childHeight

        height =
            (List.length folder.children) * (round childHeight)

        nodes =
            List.take childrenCount <|
                List.drop childrenOffset <|
                    folder.children

        spacerHeight =
            (toString (round ((toFloat childrenOffset) * childHeight))) ++ "px"

        spacerNode =
            div [ style [ ( "height", spacerHeight ) ] ] []

        contents =
            (spacerNode :: (List.map (node model folder) nodes))

        attrs =
            if isCurrent then
                [ id "__scrolling__" ]
            else
                []
    in
        div ((class "library--folder") :: attrs)
            [ div
                [ class "library--contents"
                , style
                    [ ( "height", (toString height) ++ "px" )
                    ]
                ]
                contents
            ]


libraryChildrenViewOffset : Library.Model -> Float -> ( Int, Int )
libraryChildrenViewOffset model childHeight =
    (Maybe.map2
        (\position height ->
            ( (floor <| (position / childHeight))
            , ((ceiling <| (height / childHeight)) + 2)
            )
        )
        model.scrollPosition
        model.scrollHeight
    )
        |> Maybe.withDefault ( 0, 0 )


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
        [ onWithOptions "click" options (Json.succeed (Library.ExecuteAction action title Nothing))
        , onSingleTouch (Library.ExecuteAction action title Nothing)
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
            , onClick (Library.ExecuteAction node.actions.click node.title Nothing)
            , mapTouch (Utils.Touch.touchStart (Library.ExecuteAction node.actions.click node.title Nothing))
            , mapTouch (Utils.Touch.touchEnd (Library.ExecuteAction node.actions.click node.title Nothing))
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
        div [ classList
                [ ("library--breadcrumb", True)
                , ("library--breadcrumb__search-active", model.showSearchInput)
                ]
            ]
            [ div
                [ class "library--breadcrumb--control" ]
                [ div
                    [ class "library--breadcrumb--navigation" ]
                    [ div [ classList [ ( "library--breadcrumb--dropdown", True ), ( "library--breadcrumb--dropdown__empty", dropdownEmpty ) ] ] dropdown
                    -- , span [ class "library--breadcrumb--divider" ] []
                    , div [ class "library--breadcrumb--sections" ] list
                    ]
                , (searchButton model)
                ]
            , (searchInput model)
            ]


searchButton : Library.Model -> Html Library.Msg
searchButton model =
    case Library.State.currentFolder model of
        Nothing ->
            div [] []

        Just folder ->
            case folder.search of
                Nothing ->
                    div [] []

                Just action ->
                    let
                        mapTouch a =
                            Html.Attributes.map Library.Touch a

                        msg =
                            (Library.ShowSearchInput (not model.showSearchInput))
                    in
                        div [ classList
                                [ ("library--breadcrumb-search-toggle", True)
                                , ("library--breadcrumb-search-toggle__active", model.showSearchInput)
                                ]
                            , title action.title
                            , onClick msg
                            , mapTouch (Utils.Touch.touchStart msg)
                            , mapTouch (Utils.Touch.touchEnd msg)
                            ]
                            []



searchInput : Library.Model -> Html Library.Msg
searchInput model =
    if model.showSearchInput then
        case (Library.State.currentFolder model) |> Maybe.andThen (\f -> f.search) of
            Nothing ->
                div [] []

            Just action ->
                div
                    [ class "library--breadcrumb--search-input" ]
                    [ input
                        [ class "library--search-input", type_ "text"
                        , placeholder ("Search " ++ action.title ++ "...")
                        , autofocus True
                        , value model.searchQuery
                        , onInput Library.SearchQueryUpdate
                        , onKeyDown Library.SubmitSearch Library.CancelSearch
                        ]
                        []
                    ]
    else
        div [] []



onKeyDown : Library.Msg -> Library.Msg -> Attribute Library.Msg
onKeyDown submitMsg cancelMsg =
    on "keydown" (Json.andThen (submitOrCancel submitMsg cancelMsg) keyCode)


submitOrCancel : Library.Msg -> Library.Msg -> Int -> Json.Decoder Library.Msg
submitOrCancel submitMsg cancelMsg code =
    case code of
        13 ->
            Json.succeed submitMsg

        27 ->
            Json.succeed cancelMsg

        _ ->
            Json.fail "ignored key code"
