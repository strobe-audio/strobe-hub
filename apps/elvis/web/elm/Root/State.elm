module Root.State exposing (..)

import Debug
import Window
import Root
import Root.Cmd
import Root.Events
import Channel
import Channel.State
import Receiver
import Receiver.State
import Library
import Library.State
import ID
import Input
import Input.State
import Msg exposing (Msg)
import Navigation
import Routing
import Utils.Touch
import Notification
import State
import Ports
import Settings
import Animation
import Ease
import Time


initialState : Int -> Time.Time -> Root.Model
initialState windowInnerWidth time =
    { connected = False
    , channels = []
    , receivers = []
    , listMode = State.PlaylistMode
    , showPlaylistAndLibrary = False
    , windowInnerWidth = windowInnerWidth
    , library = Library.State.initialState windowInnerWidth
    , showAddChannel = False
    , newChannelInput = Input.State.blank
    , activeChannelId = Nothing
    , touches = Utils.Touch.emptyModel
    , startTime = time
    , animationTime = time
    , notifications = []
    , viewMode = State.ViewCurrentChannel
    , showChannelControl = True
    , savedState = Nothing
    , configuration =
        { settings = Nothing
        , viewMode = Settings.Channels
        , showAddChannelInput = False
        , addChannelInput = Input.State.blank
        }
    , showHubControl = False
    , controlChannel = True
    , controlReceiver = False
    , viewAnimations =
        { revealChannelList = Animation.static 0
        , revealChannelControl = Animation.static 0
        }
    }


createSavedState : Root.Model -> Maybe Root.SavedState
createSavedState model =
    case model.activeChannelId of
        Nothing ->
            Nothing

        Just channelId ->
            let
                state =
                    { activeChannelId = channelId
                    , viewMode = State.serialiseViewMode model.viewMode
                    }
            in
                Just state


restoreSavedState : Maybe Root.SavedState -> Root.Model -> Root.Model
restoreSavedState maybeState model =
    case maybeState of
        Just state ->
            { model
                | activeChannelId = Just state.activeChannelId
                , viewMode = State.deserialiseViewMode state.viewMode
            }

        Nothing ->
            model


broadcasterState : State.BroadcasterState -> List Channel.Model
broadcasterState state =
    List.map (Channel.State.initialState (Debug.log "state" state)) state.channels


activeChannel : Root.Model -> Maybe Channel.Model
activeChannel model =
    Root.activeChannel model


updateIn : (ID.T a -> ( ID.T a, Cmd Msg )) -> ID.ID -> List (ID.T a) -> ( List (ID.T a), Cmd Msg )
updateIn update id elements =
    let
        updateElement e =
            if e.id == id then
                update e
            else
                ( e, Cmd.none )

        ( updated, cmds ) =
            (List.map updateElement elements) |> List.unzip
    in
        ( updated, Cmd.batch cmds )


updateSavingState : Msg -> Root.Model -> ( Root.Model, Cmd Msg )
updateSavingState msg model =
    let
        ( updatedModel, cmds ) =
            update msg model

        -- only send save state cmd if the state is different from the one we have
        -- already saved
        ( newModel, saveStateCmd ) =
            case createSavedState updatedModel of
                Nothing ->
                    ( updatedModel, Cmd.none )

                Just state ->
                    case model.savedState of
                        Nothing ->
                            ( { updatedModel | savedState = Just state }
                            , Ports.saveState state
                            )

                        Just modelState ->
                            if modelState /= state then
                                ( { updatedModel | savedState = Just state }
                                , Ports.saveState state
                                )
                            else
                                ( updatedModel, Cmd.none )
    in
        newModel ! [ cmds, saveStateCmd ]


update : Msg -> Root.Model -> ( Root.Model, Cmd Msg )
update action model =
    case action of
        Msg.NoOp ->
            model ! []

        Msg.Event eventResult ->
            case eventResult of
                Ok event ->
                    let
                        ( eventModel, maybeMsg, eventCmds ) =
                            Root.Events.update event model

                        ( model_, cmd ) =
                            case maybeMsg of
                                Nothing ->
                                    eventModel ! eventCmds

                                Just msg ->
                                    update msg eventModel
                    in
                        ( model_, cmd )

                Err msg ->
                    let
                        _ =
                            Debug.log "Error decoding message" msg
                    in
                        model ! []

        Msg.Connected connected ->
            let
                _ =
                    Debug.log "connected" connected
            in
                { model | connected = connected } ! []

        Msg.UrlChange location ->
            let
                updatedModel =
                    case (Routing.parseLocation location) of
                        Routing.ChannelRoute channelId ->
                            { model | activeChannelId = Just channelId }

                        _ ->
                            model
            in
                updatedModel ! []

        Msg.Receiver receiverId receiverAction ->
            let
                ( receivers, cmd ) =
                    updateIn (Receiver.State.update receiverAction) receiverId model.receivers
            in
                { model | receivers = receivers } ! [ cmd ]

        Msg.Channel channelId channelAction ->
            let
                ( channels, cmd ) =
                    updateIn (Channel.State.update channelAction) channelId model.channels
            in
                { model | channels = channels } ! [ cmd ]

        Msg.ActivateChannel channel ->
            -- { model | showAddChannel = False, activeChannelId = Just channel.id } ! []
            let
                _ =
                    Debug.log "showing channel" ( channel.id, channel.name )
            in
                { model | showAddChannel = False } ! [ Navigation.newUrl (Routing.channelLocation channel.id) ]

        Msg.AddChannel channelName ->
            model ! [ Root.Cmd.addChannel channelName ]

        Msg.SetListMode mode ->
            { model | listMode = mode } ! []

        Msg.ToggleAddChannel ->
            { model | showAddChannel = not model.showAddChannel } ! []

        Msg.AddChannelInput inputMsg ->
            let
                ( input, inputCmd, action ) =
                    Input.State.update inputMsg model.newChannelInput

                ( model_, outputMsg ) =
                    processAddChannelInputAction action { model | newChannelInput = input }

                ( updatedModel, cmd ) =
                    update outputMsg model_
            in
                ( updatedModel, Cmd.batch [ (Cmd.map Msg.AddChannelInput inputCmd), cmd ] )

        Msg.Library libraryAction ->
            let
                ( library, effect ) =
                    Library.State.update libraryAction model.library model.activeChannelId
            in
                ( { model | library = library }
                , (Cmd.map Msg.Library effect)
                )

        Msg.BroadcasterLibraryRegistration node ->
            { model | library = Library.State.add model.library node } ! []

        Msg.BrowserViewport width ->
            let
                _ =
                    Debug.log "showPlaylistAndLibrary width" width

                showPlaylistAndLibrary =
                    width > 1000

                library =
                    model.library

                library_ =
                    { library | windowInnerWidth = width }
            in
                { model
                    | windowInnerWidth = width
                    , showPlaylistAndLibrary = showPlaylistAndLibrary
                    , library = library
                }
                    ! []

        Msg.BrowserScroll value ->
            ( model, Cmd.none )

        Msg.SingleTouch te ->
            let
                touches =
                    Utils.Touch.update te model.touches

                ( updated, cmd ) =
                    case Utils.Touch.testEvent te touches of
                        Just (Utils.Touch.Tap msg) ->
                            update msg { model | touches = Utils.Touch.null }

                        _ ->
                            { model | touches = touches } ! []
            in
                updated ! [ cmd ]

        Msg.ActivateView mode ->
            let
                ( model_, cmd ) =
                    (loadSettings { model | viewMode = mode })
            in
                { model_ | showChannelControl = False } ! [ cmd ]

        Msg.ToggleShowChannelControl ->
            let
                showChannelControl =
                    not model.showChannelControl

                -- start slightly in the past to avoid awkward moment when
                -- animation declares itself to be not running as the time when
                -- it starts is exactly the current time.
                time =
                    model.animationTime - 1

                hidden =
                    1

                shown =
                    0

                makeAnimation min max =
                    Animation.animation time
                        |> Animation.from min
                        |> Animation.to max
                        |> Animation.duration 200
                        |> Animation.ease Ease.inOutQuart

                animation =
                    if showChannelControl then
                        makeAnimation hidden shown
                    else
                        makeAnimation shown hidden

                viewAnimations =
                    model.viewAnimations

                viewAnimations_ =
                    { viewAnimations | revealChannelControl = animation }
            in
                { model | showChannelControl = showChannelControl, viewAnimations = viewAnimations_ } ! []

        Msg.AnimationScroll ( time, position, height ) ->
            let
                ( library, cmd ) =
                    Library.State.update
                        (Library.AnimationFrame ( time, position, height ))
                        model.library
                        Nothing

                notifications =
                    List.filter (Notification.isVisible time) model.notifications
            in
                { model
                    | animationTime = time
                    , library = library
                    , notifications = notifications
                }
                    ! [ (Cmd.map Msg.Library cmd) ]

        Msg.LoadApplicationSettings app settings ->
            let
                _ =
                    Debug.log ("got settings " ++ app) settings

                model_ =
                    case app of
                        "otis" ->
                            let
                                configuration =
                                    model.configuration

                                configuration_ =
                                    { configuration | settings = Just settings }
                            in
                                { model | configuration = configuration_ }

                        _ ->
                            -- TODO: handle settings for libraries
                            model
            in
                model_ ! []

        Msg.UpdateApplicationSettings field value ->
            let
                configuration =
                    model.configuration

                settings =
                    case field.application of
                        "otis" ->
                            Maybe.map (Settings.updateField field value) configuration.settings

                        _ ->
                            configuration.settings

                configuration_ =
                    { configuration | settings = settings }

                cmd =
                    Maybe.map Ports.settingsSave settings
                        |> Maybe.withDefault Cmd.none
            in
                { model | configuration = configuration_ } ! [ cmd ]

        Msg.SetConfigurationViewModel mode ->
            let
                configuration =
                    model.configuration

                configuration_ =
                    { configuration | viewMode = mode }
            in
                { model | configuration = configuration_ } ! []

        Msg.ToggleShowHubControl ->
            let
                showHubControl =
                    not model.showHubControl

                -- start slightly in the past to avoid awkward moment when
                -- animation declares itself to be not running as the time when
                -- it starts is exactly the current time.
                time =
                    model.animationTime - 1

                hidden =
                    0

                shown =
                    1

                makeAnimation min max =
                    Animation.animation time
                        |> Animation.from min
                        |> Animation.to max
                        |> Animation.duration 200
                        |> Animation.ease Ease.inOutQuart

                animation =
                    if showHubControl then
                        makeAnimation hidden shown
                    else
                        makeAnimation shown hidden

                viewAnimations =
                    model.viewAnimations

                viewAnimations_ =
                    { viewAnimations | revealChannelList = animation }
            in
                { model | showHubControl = showHubControl, viewAnimations = viewAnimations_ } ! []

        Msg.ActivateControlChannel ->
            { model | controlChannel = True, controlReceiver = False } ! []

        Msg.ActivateControlReceiver ->
            { model | controlChannel = False, controlReceiver = True } ! []


libraryVisible : Root.Model -> Bool
libraryVisible model =
    case model.showPlaylistAndLibrary of
        True ->
            True

        False ->
            case model.listMode of
                State.LibraryMode ->
                    True

                State.PlaylistMode ->
                    False


processAddChannelInputAction : Maybe Input.Action -> Root.Model -> ( Root.Model, Msg )
processAddChannelInputAction action model =
    case action of
        Nothing ->
            ( model, Msg.NoOp )

        Just msg ->
            case msg of
                Input.Value name ->
                    ( model, Msg.AddChannel name )

                Input.Close ->
                    ( model, Msg.ToggleAddChannel )


loadSettings : Root.Model -> ( Root.Model, Cmd Msg )
loadSettings model =
    case model.viewMode of
        State.ViewSettings ->
            let
                configuration =
                    model.configuration

                configuration_ =
                    { configuration | settings = Nothing }
            in
                ( { model | configuration = configuration_ }, Ports.settingsRequests "otis" )

        _ ->
            ( model, Cmd.none )
