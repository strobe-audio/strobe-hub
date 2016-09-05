module Library.State exposing (..)

import ID
import Library
import Library.Cmd
import Time exposing (millisecond)


initialState : Library.Model
initialState =
  let
    root =
      { id = "libraries", title = "Libraries", icon = "", children = [] }
  in
    { levels = [ root ]
    , currentRequest = Nothing
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
          ( { model | currentRequest = Just a }
          , Cmd.batch
              [ (Library.Cmd.sendAction channelId a)
              , (Library.Cmd.requestComplete (300 * millisecond))
              ]
          )

        Nothing ->
          ( model, Cmd.none )

    Library.MaybeExecuteAction a ->
      case a of
        Nothing ->
          ( model, Cmd.none )

        Just libraryAction ->
          update (Library.ExecuteAction libraryAction) model maybeChannelId



    Library.Response folder ->
      let
        _ =
          Debug.log "current action" model.currentRequest

        model' =
          pushLevel model folder
      in
        ( { model' | currentRequest = Nothing }, Cmd.none )

    Library.PopLevel index ->
      ( { model | levels = List.drop index model.levels }, Cmd.none )


currentLevel : Library.Model -> Library.Folder
currentLevel model =
  case List.head model.levels of
    Just level ->
      level

    Nothing ->
      Debug.crash "Model has no root level!"


pushLevel : Library.Model -> Library.Folder -> Library.Model
pushLevel model folder =
  -- Debug.log ("pushLevel |" ++ (toString folder) ++ "| |" ++ (toString model.level) ++ "| ")
  { model | levels = (folder :: model.levels) }


add : Library.Model -> Library.Node -> Library.Model
add model library =
  let
    levels =
      (List.reverse model.levels)

    root =
      case (List.head levels) of
        Just level ->
          { level | children = (addUniqueLibrary library level.children) }

        Nothing ->
          Debug.crash "Model has no root level!"

    others =
      case List.tail levels of
        Just l ->
          l

        Nothing ->
          []
  in
    { model | levels = (List.reverse (root :: others)) }


addUniqueLibrary : Library.Node -> List Library.Node -> List Library.Node
addUniqueLibrary library libraries =
  let
    duplicate =
      Debug.log "Duplicate library?" (List.any (\l -> l.id == library.id) libraries)

    libraries' =
      case duplicate of
        True ->
          libraries

        False ->
          library :: libraries
  in
    libraries'
