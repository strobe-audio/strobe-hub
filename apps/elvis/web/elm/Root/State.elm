module Root.State exposing (..)

import Debug
import Window
import Root
import Root.Cmd
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


initialState : Root.Model
initialState =
    { connected = False
    , channels = []
    , receivers = []
    , listMode = State.PlaylistMode
    , showPlaylistAndLibrary = False
    , library = Library.State.initialState
    , showAddChannel = False
    , newChannelInput = Input.State.blank
    , activeChannelId = Nothing
    , showAttachReceiver = False
    , touches = Utils.Touch.emptyModel
    , animationTime = 0
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
    , showSelectChannel = False
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

        Msg.InitialState state ->
            let
                channels =
                    loadChannels model state

                receivers =
                    loadReceivers model state

                -- defaultChannelId =
                --     Maybe.map (\channel -> channel.id) (List.head channels)
                cmd =
                    gotoDefaultChannel model

                -- case model.activeChannelId of
                --     Just id ->
                --         Cmd.none
                --
                --     Nothing ->
                --         case defaultChannelId of
                --             Nothing ->
                --                 Cmd.none
                --
                --             Just id ->
                --                 Navigation.newUrl (Routing.channelLocation id)
                updatedModel =
                    { model
                        | channels = channels
                        , receivers = receivers
                    }
            in
                updatedModel ! [ cmd ]

        Msg.Receiver receiverId receiverAction ->
            let
                ( receivers, cmd ) =
                    updateIn (Receiver.State.update receiverAction) receiverId model.receivers
            in
                { model | receivers = receivers } ! [ cmd ]

        Msg.ReceiverPresence receiver ->
            let
                receivers_ =
                    if List.any (\r -> r.id == receiver.id) model.receivers then
                        model.receivers
                    else
                        (Receiver.State.initialState receiver) :: model.receivers
            in
                { model | receivers = receivers_ } ! []

        Msg.ShowAttachReceiver show ->
            { model | showAttachReceiver = show } ! []

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

        Msg.BroadcasterChannelAdded channelState ->
            let
                channel =
                    Channel.State.newChannel channelState

                model_ =
                    { model
                        | channels = channel :: model.channels
                        , newChannelInput = Input.State.blank
                    }
            in
                update (Msg.ActivateChannel channel) model_

        Msg.BroadcasterChannelRemoved channelId ->
            let
                channels =
                    List.filter (\channel -> channel.id /= channelId) model.channels

                model_ =
                    { model | channels = channels }

                -- if the channel we were on has been deleted, then reset our
                -- active channel id and goto the new default channel
                updatedModel =
                    case model.activeChannelId of
                        Just id ->
                            if id == channelId then
                                { model_ | activeChannelId = Nothing }
                            else
                                model_

                        Nothing ->
                            model_
            in
                updatedModel ! [ gotoDefaultChannel updatedModel ]

        Msg.BroadcasterChannelRenamed ( channelId, newName ) ->
            update ((Msg.Channel channelId) (Channel.Renamed newName)) model

        Msg.BroadcasterReceiverRenamed ( receiverId, newName ) ->
            update ((Msg.Receiver receiverId) (Receiver.Renamed newName)) model

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

        Msg.BroadcasterVolumeChange event ->
            case event.target of
                "receiver" ->
                    update (Msg.Receiver event.id (Receiver.VolumeChanged event.volume)) model

                "channel" ->
                    update (Msg.Channel event.id (Channel.VolumeChanged event.volume)) model

                _ ->
                    model ! []

        Msg.BroadcasterRenditionAdded rendition ->
            let
                ( model_, channelCmd ) =
                    update (Msg.Channel rendition.channelId (Channel.AddRendition rendition)) model

                notifications =
                    case model.activeChannelId of
                        Nothing ->
                            model.notifications

                        Just id ->
                            if rendition.channelId == id then
                                let
                                    notification =
                                        Debug.log "adding notification"
                                            Notification.forRendition
                                            model.animationTime
                                            rendition
                                in
                                    notification :: model.notifications
                            else
                                model.notifications
            in
                { model_ | notifications = notifications } ! [ channelCmd ]

        Msg.BrowserViewport width ->
            let
                _ =
                    Debug.log "showPlaylistAndLibrary width" width

                showPlaylistAndLibrary =
                    width > 1000
            in
                ( { model | showPlaylistAndLibrary = showPlaylistAndLibrary }, Cmd.none )

        Msg.BrowserScroll value ->
            -- let
            -- _ = Debug.log "scroll" value
            -- in
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

        Msg.ReceiverAttachmentChange ->
            case Root.activeChannel model of
                Nothing ->
                    model ! []

                Just channel ->
                    let
                        detached =
                            Receiver.detachedReceivers channel model.receivers

                        showAttachReceiver =
                            not <| List.isEmpty detached
                    in
                        { model | showAttachReceiver = showAttachReceiver } ! []

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

        Msg.ToggleShowChannelSelector ->
            let
                showSelectChannel =
                    not model.showSelectChannel

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
                    if showSelectChannel then
                        makeAnimation hidden shown
                    else
                        makeAnimation shown hidden

                viewAnimations =
                    model.viewAnimations

                viewAnimations_ =
                    { viewAnimations | revealChannelList = animation }
            in
                { model | showSelectChannel = showSelectChannel, viewAnimations = viewAnimations_ } ! []


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


loadChannels : Root.Model -> State.BroadcasterState -> List Channel.Model
loadChannels model state =
    let
        channels =
            List.map (Channel.State.initialState state) state.channels

        activeChannelId =
            Maybe.map (\channel -> channel.id) (List.head channels)
    in
        channels


loadReceivers : Root.Model -> State.BroadcasterState -> List Receiver.Model
loadReceivers model state =
    List.map Receiver.State.initialState state.receivers


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


gotoDefaultChannel : Root.Model -> Cmd Msg
gotoDefaultChannel model =
    case model.activeChannelId of
        Just id ->
            Cmd.none

        Nothing ->
            let
                defaultChannelId =
                    Maybe.map (\channel -> channel.id) (List.head model.channels)
            in
                case defaultChannelId of
                    Nothing ->
                        Cmd.none

                    Just id ->
                        Navigation.newUrl (Routing.channelLocation id)
