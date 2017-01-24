module Library.State exposing (..)

import ID
import Library
import Library.Cmd
import Time exposing (millisecond)
import Debug
import Utils.Touch
import Stack exposing (Stack)
import Animation
import Ease


initialState : Library.Model
initialState =
    let
        rootFolder =
            { id = "libraries", title = "Libraries", icon = "", children = [] }

        root =
            { action = "root", title = rootFolder.title, contents = Just rootFolder }

        levels =
            Stack.initialise |> Stack.push root
    in
        { levels = levels
        , depth = 0
        , currentRequest = Nothing
        , unloadingLevel = Nothing
        , touches = Utils.Touch.emptyModel
        , animationTime = Nothing
        , scrollPosition = Nothing
        , scrollHeight = Nothing
        , levelAnimation = (Animation.static 0)
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

        Library.ExecuteAction a title ->
            case maybeChannelId of
                Just channelId ->
                    let
                        model_ =
                            if a.level then
                                let
                                    level =
                                        { action = a.url, title = title, contents = Nothing }

                                    levels =
                                        Stack.push level model.levels

                                    animation =
                                        levelAnimation model (model.depth + 1)
                                in
                                    { model
                                        | levels = levels
                                        , depth = model.depth + 1
                                        , levelAnimation = animation
                                    }
                            else
                                model
                    in
                        { model_ | currentRequest = Just a.url } ! [ (Library.Cmd.sendAction channelId a.url) ]

                -- disable this auto-completion as I need the currentRequest value
                -- , (Library.Cmd.requestComplete (300 * millisecond))
                Nothing ->
                    ( model, Cmd.none )

        Library.MaybeExecuteAction a title ->
            case a of
                Nothing ->
                    ( model, Cmd.none )

                Just libraryAction ->
                    update (Library.ExecuteAction libraryAction title) model maybeChannelId

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
                                ( { model_ | currentRequest = Nothing }, Cmd.none )

        Library.PopLevel index ->
            let
                model_ =
                    case model.depth of
                        0 ->
                            model

                        _ ->
                            let
                                ( maybeCurrentLevel, levels ) =
                                    Stack.pop model.levels

                                animation =
                                    levelAnimation model (model.depth - 1)
                            in
                                { model
                                    | levels = levels
                                    , depth = (max 0 model.depth - 1)
                                    , levelAnimation = animation
                                    , unloadingLevel = maybeCurrentLevel
                                }
            in
                ( model_, Cmd.none )

        Library.Touch te ->
            let
                touches =
                    Debug.log "touches" (Utils.Touch.update te model.touches)

                ( updated_, cmd_ ) =
                    case Utils.Touch.testEvent te touches of
                        _ ->
                            { model | touches = touches } ! []

                -- change to click type
                ( updated, cmd ) =
                    case Utils.Touch.isSingleClick te touches of
                        Nothing ->
                            { model | touches = touches } ! []

                        Just msg ->
                            update msg { model | touches = Utils.Touch.emptyModel } maybeChannelId
            in
                ( updated, cmd )

        Library.AnimationFrame (time, scrollPosition, scrollHeight) ->
            let
                model_ =
                    if Animation.isDone time model.levelAnimation then
                        { model | unloadingLevel = Nothing }
                    else
                        model
            in
                { model_
                | animationTime = Just time
                , scrollPosition = Just scrollPosition
                , scrollHeight = Just scrollHeight
                } ! []


currentLevel : Library.Model -> Library.Level
currentLevel model =
    case List.head <| Stack.toList model.levels of
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
            (List.map updateLevel) <| (Stack.toList model.levels)
    in
        { model | levels = (Stack.fromList levels) }


add : Library.Model -> Library.Node -> Library.Model
add model library =
    let
        reversedLevels =
            List.reverse <| Stack.toList model.levels

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
            Stack.fromList (List.reverse (root :: others))
    in
        { model | levels = levels }


addUniqueLibrary : Library.Node -> Library.Folder -> Library.Folder
addUniqueLibrary library folder =
    let
        duplicate =
            Debug.log "Duplicate library?" (List.any (\l -> l.id == library.id) folder.children)

        children =
            case duplicate of
                True ->
                    folder.children

                False ->
                    library :: folder.children
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
                |> Animation.duration (200 * Time.millisecond)
                |> Animation.ease Ease.inOutSine
        )
        model.animationTime
    )
        |> Maybe.withDefault (Animation.static (levelOffset model.depth))
