module Library.State exposing (..)

import ID
import Library
import Library.Cmd
import Time exposing (millisecond)
import Debug
import Utils.Touch
import Animation
import Ease
import Task
import Process
import Maybe.Extra


initialState : Library.Model
initialState =
    let
        rootFolder =
            { id = "libraries", title = "Libraries", icon = "", children = [], search = Nothing }

        root =
            { action = "root", title = rootFolder.title, contents = Just rootFolder, scrollPosition = 0, scrollHeight = 0, visible = True }

        levels =
            [ root ]
    in
        { levels = levels
        , depth = 0
        , currentRequest = Nothing
        , unloadingLevel = Nothing
        , touches = Utils.Touch.emptyModel
        , animationTime = Nothing
        , levelAnimation = (Animation.static 0)
        , showSearchInput = False
        , searchQuery = ""
        , searchBounceCount = 0
        , scrollMomentum = Nothing
        , scrollInteraction = Library.MouseScroll
        }


update : Library.Msg -> Library.Model -> Maybe ID.Channel -> ( Library.Model, Cmd Library.Msg )
update action model maybeChannelId =
    case action of
        Library.NoOp ->
            ( model, Cmd.none )

        Library.ActionComplete ->
            let
                _ =
                    Debug.log "action complete" model.currentRequest
            in
                ( { model | currentRequest = Nothing }, Cmd.none )

        Library.ExecuteAction a title query ->
            case maybeChannelId of
                Just channelId ->
                    let
                        model_ =
                            if a.level then
                                let
                                    hiddenLevels =
                                        List.map (\l -> { l | visible = False }) model.levels

                                    level =
                                        { action = a.url, title = title, contents = Nothing, scrollHeight = 0, scrollPosition = 0, visible = True }

                                    levels =
                                        level :: hiddenLevels

                                    animation =
                                        levelAnimation model (model.depth + 1)
                                in
                                    { model
                                        | levels = levels
                                        , depth = model.depth + 1
                                        , levelAnimation = animation
                                        , scrollMomentum = Nothing
                                    }
                            else
                                model
                    in
                        { model_ | currentRequest = Just a.url } ! [ (Library.Cmd.sendAction channelId a.url query) ]

                -- disable this auto-completion as I need the currentRequest value
                -- , (Library.Cmd.requestComplete (300 * millisecond))
                Nothing ->
                    ( model, Cmd.none )

        Library.MaybeExecuteAction a title ->
            case a of
                Nothing ->
                    ( model, Cmd.none )

                Just libraryAction ->
                    update (Library.ExecuteAction libraryAction title Nothing) model maybeChannelId

        Library.Response url folderResponse ->
            case model.currentRequest of
                Nothing ->
                    model ! []

                Just action ->
                    case folderResponse of
                        Nothing ->
                            ( { model | currentRequest = Nothing }, Cmd.none )

                        Just folder ->
                            let
                                model_ =
                                    setLevelContents model action folder
                            in
                                ( { model_ | currentRequest = Nothing, scrollMomentum = Nothing }, Cmd.none )

        Library.PopLevel index ->
            let
                ( model_, cmd_ ) =
                    case model.depth of
                        0 ->
                            ( model, Cmd.none )

                        _ ->
                            let
                                ( maybeCurrentLevel, levels ) =
                                    case model.levels of
                                        l :: active :: rest ->
                                            ( Just l, ({ active | visible = True } :: rest) )

                                        l :: rest ->
                                            ( Just l, rest )

                                        l ->
                                            ( Nothing, l )

                                animation =
                                    levelAnimation model (model.depth - 1)
                            in
                                ( { model
                                    | levels = levels
                                    , depth = (max 0 model.depth - 1)
                                    , levelAnimation = animation
                                    , unloadingLevel = maybeCurrentLevel
                                    , scrollMomentum = Nothing
                                    , showSearchInput = False
                                  }
                                , Library.Cmd.blurSearch True
                                )
            in
                ( model_, cmd_ )

        Library.Touch te ->
            let
                touches =
                    (Utils.Touch.update te model.touches)
            in
                case Utils.Touch.testEvent te touches of
                    Just (Utils.Touch.TouchStart msg) ->
                        { model | scrollMomentum = Nothing, touches = { touches | savedMomentum = model.scrollMomentum } } ! []

                    Just (Utils.Touch.Swipe (Utils.Touch.Y) direction dy y msg) ->
                        let
                            levels =
                                case model.levels of
                                    level :: rest ->
                                        let
                                            level_ =
                                                { level | scrollPosition = (min 0 (level.scrollPosition + dy)) }
                                        in
                                            level_ :: rest

                                    [] ->
                                        model.levels
                        in
                            { model | scrollMomentum = Nothing, touches = touches, levels = levels } ! []

                    Just (Utils.Touch.Tap msg) ->
                        -- if there was a momentum scroll in progress when the
                        -- touch started then prevent taps from doing anything:
                        -- they should just kill the scroll
                        case (Maybe.Extra.or model.scrollMomentum touches.savedMomentum) of
                            Nothing ->
                                update
                                    msg
                                    { model
                                        | touches = Utils.Touch.emptyModel
                                        , scrollMomentum = Nothing
                                    }
                                    maybeChannelId

                            Just m ->
                                { model
                                    | touches = Utils.Touch.emptyModel
                                    , scrollMomentum = Nothing
                                }
                                    ! []

                    Just (Utils.Touch.Flick newMomentum msg) ->
                        let
                            scrollMomentum =
                                case model.levels of
                                    level :: rest ->
                                        (Just
                                            (newMomentum
                                                (Maybe.withDefault 0.0 model.animationTime)
                                                level.scrollPosition
                                                touches.savedMomentum
                                            )
                                        )

                                    _ ->
                                        Nothing
                        in
                            { model | touches = { touches | savedMomentum = Nothing }, scrollMomentum = scrollMomentum } ! []

                    _ ->
                        { model | touches = { touches | savedMomentum = Nothing } } ! []

        Library.AnimationFrame ( time, scrollTop, scrollHeight ) ->
            let
                ( levels, scrollMomentum ) =
                    -- scrollTop is Nothing for mobile/touch browsers where scroll is handled by elm
                    -- and Just position for desktop browsers where scroll is done by mouse
                    case scrollTop of
                        Nothing ->
                            case model.levels of
                                current :: rest ->
                                    let
                                        scrollPosition =
                                            (Maybe.map4
                                                Utils.Touch.scrollPosition
                                                model.animationTime
                                                model.scrollMomentum
                                                (Library.levelContentHeight current)
                                                (Just current.scrollHeight)
                                            )
                                    in
                                        case scrollPosition of
                                            Just (Utils.Touch.Scrolling momentum) ->
                                                ( ({ current | scrollHeight = scrollHeight, scrollPosition = momentum.position } :: rest)
                                                , Just momentum
                                                )

                                            Just (Utils.Touch.ScrollComplete position) ->
                                                ( ({ current | scrollHeight = scrollHeight, scrollPosition = position } :: rest)
                                                , Nothing
                                                )

                                            Nothing ->
                                                ( ({ current | scrollHeight = scrollHeight, scrollPosition = current.scrollPosition } :: rest)
                                                , model.scrollMomentum
                                                )

                                [] ->
                                    ( [], model.scrollMomentum )

                        Just position ->
                            case model.levels of
                                current :: rest ->
                                    ( ({ current | scrollHeight = scrollHeight, scrollPosition = position } :: rest)
                                    , Nothing
                                    )

                                [] ->
                                    ( [], Nothing )

                model_ =
                    if Animation.isDone time model.levelAnimation then
                        { model | levels = levels, unloadingLevel = Nothing }
                    else
                        model

                scrollInteraction =
                    Maybe.map (always Library.MouseScroll) scrollTop
                        |> Maybe.withDefault Library.TouchScroll
            in
                { model_
                    | animationTime = Just time
                    , scrollMomentum = scrollMomentum
                    , scrollInteraction = scrollInteraction
                }
                    ! []

        Library.ShowSearchInput show ->
            { model | showSearchInput = show } ! [ Library.Cmd.blurSearch (not show) ]

        Library.SearchQueryUpdate query ->
            let
                newCount =
                    model.searchBounceCount + 1

                cmd =
                    Task.perform
                        (always (Library.SearchTimeout newCount))
                        (Process.sleep 250)
            in
                { model | searchQuery = query, searchBounceCount = newCount } ! [ cmd ]

        Library.SubmitSearch ->
            -- TODO: send search query
            (submitSearch model maybeChannelId)

        Library.CancelSearch ->
            { model | showSearchInput = False, searchQuery = "" } ! [ Library.Cmd.blurSearch True ]

        Library.SearchTimeout count ->
            let
                ( model_, cmd ) =
                    if count == model.searchBounceCount then
                        (submitSearch model maybeChannelId)
                    else
                        model ! []
            in
                ( model_, cmd )


currentLevel : Library.Model -> Library.Level
currentLevel model =
    case List.head <| model.levels of
        Just level ->
            level

        Nothing ->
            Debug.crash "Model has no root level!"


setLevelContents : Library.Model -> Library.ActionURL -> Library.Folder -> Library.Model
setLevelContents model action folder =
    let
        updateLevel l =
            if l.action == action then
                { l | contents = Just folder }
            else
                l

        levels =
            (List.map updateLevel) model.levels
    in
        { model | levels = levels }


add : Library.Model -> Library.Section -> Library.Model
add model library =
    let
        reversedLevels =
            List.reverse model.levels

        root =
            case (List.head reversedLevels) of
                Just level ->
                    case level.contents of
                        Nothing ->
                            level

                        Just folder ->
                            { level | contents = Just (addUniqueLibrary library folder) }

                Nothing ->
                    Debug.crash "Model has no root level!"

        others =
            case List.tail reversedLevels of
                Just l ->
                    l

                Nothing ->
                    []

        levels =
            List.reverse (root :: others)
    in
        { model | levels = levels }


addUniqueLibrary : Library.Section -> Library.Folder -> Library.Folder
addUniqueLibrary section folder =
    let
        duplicate =
            Debug.log "Duplicate library?" (List.any (\l -> l.id == section.id) folder.children)

        children =
            case duplicate of
                True ->
                    folder.children

                False ->
                    section :: folder.children
    in
        { folder | children = children }


levelOffset : Int -> Float
levelOffset depth =
    (depth * 100) |> toFloat


levelAnimation : Library.Model -> Int -> Animation.Animation
levelAnimation model targetDepth =
    (Maybe.map
        (\time ->
            (Animation.animation time)
                |> (Animation.from (levelOffset model.depth))
                |> Animation.to (levelOffset targetDepth)
                |> Animation.duration (300 * Time.millisecond)
                |> Animation.ease Ease.inOutSine
        )
        model.animationTime
    )
        |> Maybe.withDefault (Animation.static (levelOffset model.depth))


currentFolder : Library.Model -> Maybe Library.Folder
currentFolder model =
    model.levels
        |> List.head
        |> Maybe.andThen (\l -> l.contents)


submitSearch : Library.Model -> Maybe ID.Channel -> ( Library.Model, Cmd Library.Msg )
submitSearch model channelId =
    if (String.length model.searchQuery) < 3 then
        model ! []
    else
        submitValidSearch model channelId


submitValidSearch : Library.Model -> Maybe ID.Channel -> ( Library.Model, Cmd Library.Msg )
submitValidSearch model channelId =
    let
        folder =
            (currentFolder model)

        searchAction =
            folder |> Maybe.andThen (\f -> f.search)
    in
        case searchAction of
            Nothing ->
                model ! []

            Just action ->
                let
                    addLevel =
                        case folder of
                            Nothing ->
                                True

                            Just f ->
                                not <| (f.id == action.url)

                    a =
                        Library.ExecuteAction
                            { url = action.url, level = addLevel }
                            ("Search " ++ action.title)
                            (Just model.searchQuery)
                in
                    (update a model channelId)
