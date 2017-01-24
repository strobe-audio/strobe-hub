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
    , animationTime = Nothing
    , notifications = []
    -- NEW
    , viewMode = State.ViewCurrentChannel
    , showChannelControl = True
    }


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

                defaultChannelId =
                    Maybe.map (\channel -> channel.id) (List.head channels)

                cmd =
                    case model.activeChannelId of
                        Just id ->
                            Cmd.none

                        Nothing ->
                            case defaultChannelId of
                                Nothing ->
                                    Cmd.none

                                Just id ->
                                    Navigation.newUrl (Routing.channelLocation id)

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
                    { model | channels = channel :: model.channels }
            in
                update (Msg.ActivateChannel channel) model_

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
            { model | showChannelControl = False, viewMode = mode } ! []

        Msg.ToggleShowChannelControl ->
            { model | showChannelControl = not model.showChannelControl } ! []

        Msg.ReceiverAttachmentChange ->
            case Root.activeChannel model of
                Nothing ->
                    model ! []

                Just channel ->
                    let
                        detached =
                            Receiver.detachedReceivers model.receivers channel

                        showAttachReceiver =
                            not <| List.isEmpty detached
                    in

                        { model | showAttachReceiver = showAttachReceiver } ! []

        Msg.AnimationScroll (time, position, height) ->
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
                    | animationTime = Just time
                    , library = library
                    , notifications = notifications
                }
                    ! [ (Cmd.map Msg.Library cmd) ]


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
