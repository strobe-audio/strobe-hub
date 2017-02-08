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
import Debug exposing (log)


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
            model.levels
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

        view =
            (folderView level folder)


        offset =
            level.scrollPosition + view.firstNodePosition

        contents =
            (List.map (renderable model folder) view.renderable)

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
                gap = 2

                totalHeight =
                    Library.folderContentHeight folder

                totalCount =
                    Library.folderContentCount folder

                visible =
                    level.scrollHeight < totalHeight

                height =
                    ( ((List.length view.renderable |> toFloat) / (totalCount |> toFloat)) * level.scrollHeight )
                    |> (Basics.max 20)

                scrollHeight =
                    level.scrollHeight - 2 * gap

                position =
                    (( (abs level.scrollPosition) / (totalHeight - scrollHeight) ) * (scrollHeight - height)) + gap

            in
                if visible then
                    case model.scrollMomentum of
                        Nothing ->
                            scrollThumb height position True

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
                        [ classList
                            [ ("library--contents", True)
                            , ("library--scrolling", model.scrollMomentum |> Maybe.map (always True) |> Maybe.withDefault False )
                            ]
                        , style
                            [ ( "height", (toString height) ++ "px" )
                            , ( "transform", "translateY(" ++ (toString (offset)) ++ "px)" )
                            ]
                        ]
                        contents
                    , thumb
                    ]
            ) level.action level.scrollPosition


folderView : Library.Level -> Library.Folder -> Library.FolderView
folderView level folder =
    -- find section that holdds the current offest
    let
        (renderable, firstNodePosition) =
            folderViewOpenWindow level folder.children 0.0

        height =
            Library.renderableHeight renderable

    in
        { renderable = renderable, height = height, firstNodePosition = firstNodePosition }



folderViewOpenWindow : Library.Level -> List Library.Section -> Float -> (List Library.Renderable, Float)
folderViewOpenWindow level sections height =
    case sections of
        [] ->
            -- so we've run out of sections and we're still not able to reach
            -- the start of the scrollable offset -- BUG
            Debug.log "library has scrolled out of view" ([], 0.0)

        section :: rest ->
            let
                sectionHeight =
                    Library.sectionHeight section

                sectionCover =
                    height + sectionHeight

            in
                if sectionCover < (abs level.scrollPosition) then
                    folderViewOpenWindow level rest sectionCover
                else
                    folderViewFillWindow sections height ((abs level.scrollPosition) - height) level.scrollHeight []


folderViewFillWindow : List Library.Section -> Float -> Float -> Float -> List Library.Renderable -> (List Library.Renderable, Float)
folderViewFillWindow sections position offset height renderable =
    case sections of
        section :: rest ->
            let

                ( r, firstNodePosition, remainingHeight ) =
                    (sectionRenderable section position offset height)

                renderable_ =
                    (List.append renderable r)

                -- we're returning the position of the first renderable so
                -- don't update this once we have it
                newPosition =
                    case renderable of
                        [] ->
                            firstNodePosition
                        _ ->
                            position
            in
                if remainingHeight > 0 then
                    folderViewFillWindow rest newPosition 0.0 remainingHeight  renderable_
                else
                    (renderable_, newPosition)

        [] ->
            (renderable, position)


sectionRenderable : Library.Section -> Float -> Float -> Float -> (List Library.Renderable, Float, Float)
sectionRenderable section position offset height =
    let
        ( skipHead, skipChild ) =
            sectionContentOffset section offset

        headHeight =
            Library.sectionNodeHeight section

        headOverlap =
            case skipHead of
                False ->
                    0
                True ->
                    headHeight

        firstChildOffset =
            headOverlap + ((toFloat skipChild) * Library.nodeHeight)

        overlap =
            offset - firstChildOffset

        nodeHeight =
            Library.nodeHeight

        sectionOffset =
            position + firstChildOffset


        fillHeight =
            height + overlap
    in
        if ((Library.sectionHeight section) - offset) > height then
            -- take a subset
            let

                childNodes : Int -> Int -> List Library.Renderable
                childNodes drop take =
                    Library.sliceSection drop take section

                renderable =
                    case skipHead of
                        True ->
                            let
                                take =
                                    (fillHeight / nodeHeight) |> ceiling
                            in
                                (childNodes skipChild take)

                        False ->
                            let
                                take =
                                    ((fillHeight - headHeight) / nodeHeight) |> ceiling
                            in
                                (Library.S section) :: (childNodes skipChild take)


            in
                ( renderable, sectionOffset, 0.0 )

        else
            -- return all elements in section and remaining height
            let
                children =
                    Library.dropSection skipChild section

                renderable =
                    case skipHead of
                        False ->
                            (Library.S section) :: children

                        True ->
                            children

                sectionHeight =
                    fillHeight - (Library.renderableHeight renderable)
            in
                ( renderable,  sectionOffset, sectionHeight )


-- number of (head, child) nodes to skip when taking the section
-- contents at a givein pixel offset
sectionContentOffset : Library.Section -> Float -> (Bool, Int)
sectionContentOffset section offset =
    let
        headHeight =
            Library.sectionNodeHeight section

    in
        if offset < headHeight then
            (False, 0)
        else
            let
                nodeCount =
                    ((offset - headHeight) / Library.nodeHeight) |> floor
            in
                (True, nodeCount)


metadata : Maybe (List Library.Metadata) -> Html Library.Msg
metadata metadata =
    case metadata of
        Nothing ->
            div [] []

        Just metadataGroups ->
            div [ class "library--node--metadata" ] (List.map metadataGroup metadataGroups)


metadataClick : String -> Library.Action -> List (Html.Attribute Library.Msg)
metadataClick title action =
    let
        options =
            { preventDefault = True, stopPropagation = True }
    in
        [ onWithOptions "click" options (Json.succeed (Library.ExecuteAction action title Nothing))
        , onSingleTouch (Library.ExecuteAction action title Nothing)
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
                            ([ class "library--click-action" ] ++ (metadataClick link.title action))
            in
                (a attrs [ text link.title ])

        links =
            List.map makeLink group
    in
        div [ class "library--node--metadata-group" ] links


renderable : Library.Model -> Library.Folder -> Library.Renderable -> (String, Html Library.Msg)
renderable model folder renderable =
    case renderable of
        -- TODO: this should return an (id, html) pair suitable for use by keyed
        Library.N id n ->
            (id, node model folder n )

        Library.S s ->
            (s.id, section model folder s )


section : Library.Model -> Library.Folder -> Library.Section -> Html Library.Msg
section model folder section =
    case section.size of
        "m" ->
            let
                n =
                    -- { id = section.id
                    { title = section.title
                    , icon = Maybe.withDefault "" section.icon
                    , actions = Maybe.withDefault Library.defaultNodeActions section.actions
                    , metadata = section.metadata
                    }
            in
                Library.sectionNode section |> node model folder

        "h" ->
            sectionHuge model folder section

        "s" ->
            sectionSmall model folder section

        s ->
            div
                [ class ("library--section--" ++ s)
                , mapTouch (Utils.Touch.touchStart Library.NoOp)
                , mapTouch (Utils.Touch.touchMove Library.NoOp)
                , mapTouch (Utils.Touch.touchEnd Library.NoOp)
                ]
                [ text section.title ]


sectionSmall : Library.Model -> Library.Folder -> Library.Section -> Html Library.Msg
sectionSmall model folder section =
    div
        [ class ("library--section--s")
        , mapTouch (Utils.Touch.touchStart Library.NoOp)
        , mapTouch (Utils.Touch.touchMove Library.NoOp)
        , mapTouch (Utils.Touch.touchEnd Library.NoOp)
        ]
        [ text section.title ]

sectionHuge : Library.Model -> Library.Folder -> Library.Section -> Html Library.Msg
sectionHuge model folder section =
    let
        playMsg =
            case section.actions of
                Nothing ->
                    Library.NoOp

                Just actions ->
                    (Library.MaybeExecuteAction actions.play section.title)

        metadata_ =
            div
                [ class "library--section--h--text" ]
                [ div
                    [ class "library--section--h--metadata" ]
                    [ div
                        [ class "library--section--h--title" ]
                        [ text section.title ]
                    , (metadata section.metadata)
                    ]
                , div
                    [ class "library--section--h--play"
                    , onClick playMsg
                    , mapTouch (Utils.Touch.touchStart playMsg)
                    , mapTouch (Utils.Touch.touchEnd playMsg)
                    ]
                    []
                ]

        cover =
            case section.icon of
                Nothing ->
                    div [] []

                Just url ->
                    div [ class "library--section--h--icon"
                        , style [("backgroundImage", Utils.Css.url url)]
                        ]
                        [ metadata_ ]
    in
        div
            [ class ("library--section--h")
            , mapTouch (Utils.Touch.touchStart Library.NoOp)
            , mapTouch (Utils.Touch.touchMove Library.NoOp)
            , mapTouch (Utils.Touch.touchEnd Library.NoOp)
            ]
            [ cover ]


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
                , (metadata node.metadata)
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
            model.levels
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


mapTouch : Attribute (Utils.Touch.E Library.Msg) -> Attribute Library.Msg
mapTouch a =
    Html.Attributes.map Library.Touch a
