module Library.View exposing (..)

import Html exposing (..)
import Html.Lazy exposing (lazy, lazy2, lazy3)
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
                    , (folder model l folder_ isCurrent)
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
            [ class "library--levels", style [ ( "transform", "translateX(" ++ (toString left) ++ "vw)" ) ] ]
            columns


folder : Library.Model -> Library.Level -> Library.Folder -> Bool -> Html Library.Msg
folder model level folder isCurrent =
    let
        childHeight =
            Library.nodeHeight

        ( childrenOffset, childrenCount ) =
            libraryChildrenViewOffset level childHeight

        height =
            childrenCount * (round childHeight)

        mod =
            (toFloat ((ceiling (level.scrollPosition / childHeight)) * (round childHeight)))

        offset =
            level.scrollPosition - mod

        nodes =
            List.take childrenCount <|
                List.drop childrenOffset <|
                    folder.children

        contents =
            ((List.map (\n -> (n.id, (node model folder n) ) ) nodes))

        attrs =
            if isCurrent then
                [ id "__scrollable__" ]
            else
                []

        scrollThumb height top active =
            div
                [ classList
                    [ ("library--scroll-thumb", True)
                    , ("library--scroll-thumb__active", active)
                    , ("library--scroll-thumb__inactive", not active)
                    ]
                , style
                    [ ("height", (toString height) ++ "px")
                    , ("top", (toString top) ++ "px")
                    ]
                ]
                []

        thumb =
            let

                c =
                    (folder.children |> List.length |> toFloat)

                visible =
                    childrenCount < (List.length folder.children)

                height =
                    ( (childrenCount |> toFloat) / c )
                    |> (Basics.max 40)

                position =
                    ( ((toFloat (childrenOffset)) /  c) * (level.scrollHeight - height - 2) ) + 2

            in
                if visible then
                    case model.scrollMomentum of
                        Nothing ->
                            scrollThumb height position False

                        Just momentum ->
                            scrollThumb height position True
                else
                    div [] []
    in
        lazy2
            (\ac sp ->
                div ((class "library--folder") :: attrs)
                    [ Html.Keyed.node
                        "div"
                        [ class "library--contents"
                        , style
                            [ ( "height", (toString height) ++ "px" )
                            , ( "transform", "translateY(" ++ (toString (offset)) ++ "px)" )
                            ]
                        ]
                        contents
                    , thumb
                    ]
            ) level.action level.scrollPosition


libraryChildrenViewOffset : Library.Level -> Float -> ( Int, Int )
libraryChildrenViewOffset level childHeight =
    ( (floor <| ((abs level.scrollPosition) / childHeight))
    , ((ceiling <| (level.scrollHeight / childHeight)) + 2)
    )


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

        nodeStyle =
            if Utils.Touch.slowScroll library.scrollMomentum then
                [ ( "backgroundImage", (Utils.Css.url node.icon) ) ]
            else
                []
    in
        div
            [ classList
                [ ( "library--node", True )
                , ( "library--node__active", isActive )
                , ( "library--click-action", True )
                ]
            , onClick (Library.ExecuteAction node.actions.click node.title Nothing)
            , mapTouch (Utils.Touch.touchStart (Library.ExecuteAction node.actions.click node.title Nothing))
            , mapTouch (Utils.Touch.touchMove Library.NoOp)
            , mapTouch (Utils.Touch.touchEnd (Library.ExecuteAction node.actions.click node.title Nothing))
            ]
            [ div
                [ class "library--node--icon"
                , style nodeStyle
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
                , ("library--breadcrumb__search-active", (showSearchInput model))
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


showSearchInput : Library.Model -> Bool
showSearchInput model =
    case model.showSearchInput of
        False ->
            False

        True ->
            case (Library.State.currentFolder model) |> Maybe.andThen (\f -> f.search) of
                Nothing ->
                    False

                Just a ->
                    True


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
