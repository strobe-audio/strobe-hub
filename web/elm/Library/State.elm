module Library.State exposing (..)

import ID
import Library
import Library.Cmd
import Time exposing (millisecond)
import Debug
import Utils.Touch
import Stack exposing (Stack)


initialState : Library.Model
initialState =
    let
        rootFolder =
            { id = "libraries", title = "Libraries", icon = "", children = [] }

        root =
            { action = "root", contents = Just rootFolder }
        levels =
            Stack.initialise |> Stack.push root
    in
        { levels = levels
        , depth = 0
        , currentRequest = Nothing
        , touches = Utils.Touch.emptyModel
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

        Library.ExecuteAction a ->
            case maybeChannelId of
                Just channelId ->
                    let
                        level =
                            { action = a, contents = Nothing }

                        levels =
                            Stack.push level model.levels

                        model_ =
                            { model
                            | currentRequest = Just a
                            , levels = levels
                            , depth = model.depth + 1
                            }
                    in
                        model_ ! [ (Library.Cmd.sendAction channelId a) ]
                        -- disable this auto-completion as I need the currentRequest value
                        -- , (Library.Cmd.requestComplete (300 * millisecond))

                Nothing ->
                    ( model, Cmd.none )

        Library.MaybeExecuteAction a ->
            case a of
                Nothing ->
                    ( model, Cmd.none )

                Just libraryAction ->
                    update (Library.ExecuteAction libraryAction) model maybeChannelId

        Library.Response folder ->
            case model.currentRequest of
                Nothing ->
                    model ! []

                Just action ->
                    let
                        _ =
                            Debug.log "current action" action

                        model_ =
                            setLevelContents model action folder
                    in
                        ( { model_ | currentRequest = Nothing }, Cmd.none )

        Library.PopLevel index ->
            let
                levels = case model.depth of
                    0 ->
                        model.levels
                    _ ->
                        let
                            (_, levels) = Stack.pop model.levels
                        in
                            levels

            in
                ( { model | levels = levels, depth = (max 0 model.depth - 1) }, Cmd.none )

        Library.Touch te ->
          let
              touches =
                Debug.log "touches" (Utils.Touch.update te model.touches)

              (updated_, cmd_) = case Utils.Touch.testEvent te touches of
                  _ ->
                    { model | touches = touches  } ! []

              -- change to click type
              (updated, cmd) = case Utils.Touch.isSingleClick te touches of
                Nothing ->
                  { model | touches = touches  } ! []

                Just msg ->
                  update msg { model | touches = Utils.Touch.emptyModel } maybeChannelId


          in
                (updated, cmd)


currentLevel : Library.Model -> Library.Level
currentLevel model =
    case List.head <| Stack.toList model.levels of
        Just level ->
            level

        Nothing ->
            Debug.crash "Model has no root level!"

setLevelContents : Library.Model -> Library.Action -> Library.Folder -> Library.Model
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

pushLevel : Library.Model -> Library.Action -> Library.Folder -> Library.Model
pushLevel model action folder =
    let
        level =
            { action = action, contents = Just folder }

        levels =
            Stack.push level model.levels

    in
        -- Debug.log ("pushLevel |" ++ (toString folder) ++ "| |" ++ (toString model.level) ++ "| ")
        { model
        | depth = model.depth + 1
        , levels = levels
        }


add : Library.Model -> Library.Node -> Library.Model
add model library =
    let

        _ = Debug.log "library" model

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
