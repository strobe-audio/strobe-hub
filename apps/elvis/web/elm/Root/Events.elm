module Root.Events exposing (update)

import Input.State
import Msg exposing (Msg)
import Root
import Channel
import Channel.State
import Receiver
import Receiver.State
import Rendition
import State
import Task
import Notification


-- type Action
--     =


update : State.Event -> Root.Model -> ( Root.Model, Maybe Msg, List (Cmd Msg) )
update action model =
    case action of
        State.Startup channelStates receiverStates renditionStates ->
            let
                model_ =
                    { model
                        | channels = (loadChannels channelStates renditionStates)
                        , receivers = (loadReceivers receiverStates)
                    }
            in
                ( model_, Nothing, [ Root.gotoDefaultChannel model_ ] )

        State.Volume event ->
            let
                msg =
                    case event.target of
                        "receiver" ->
                            Msg.Receiver event.id (Receiver.VolumeChanged event.volume)

                        "channel" ->
                            Msg.Channel event.id (Channel.VolumeChanged event.volume)

                        _ ->
                            Msg.NoOp
            in
                ( model, Just msg, [] )

        State.ReceiverAdd receiverId channelId ->
            ( model, Just (Msg.Receiver receiverId (Receiver.Online channelId)), [] )

        State.ReceiverRemove receiverId ->
            ( model, Just (Msg.Receiver receiverId Receiver.Offline), [] )

        State.ReceiverAttach receiverId channelId ->
            ( model, Just (Msg.Receiver receiverId (Receiver.Attached channelId)), [] )

        State.ReceiverOnline receiver ->
            let
                receivers_ =
                    if List.any (\r -> r.id == receiver.id) model.receivers then
                        model.receivers
                    else
                        (Receiver.State.initialState receiver) :: model.receivers
            in
                ( { model | receivers = receivers_ }, Nothing, [] )

        State.ReceiverRename receiverId name ->
            ( model, Just (Msg.Receiver receiverId (Receiver.Renamed name)), [] )

        State.ReceiverMute receiverId muted ->
            ( model, Just (Msg.Receiver receiverId (Receiver.Muted muted)), [] )

        State.ChannelPlayPause channelId playing ->
            ( model, Just (Msg.Channel channelId (Channel.IsPlaying playing)), [] )

        State.ChannelAdd channelState ->
            let
                channel =
                    Channel.State.newChannel channelState

                model_ =
                    { model
                        | channels = channel :: model.channels
                        , newChannelInput = Input.State.blank
                    }
            in
                ( model_, Just (Msg.ActivateChannel channel), [] )

        State.ChannelRemove channelId ->
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
                ( updatedModel, Nothing, [ Root.gotoDefaultChannel updatedModel ] )

        State.ChannelRename channelId name ->
            ( model, Just (Msg.Channel channelId (Channel.Renamed name)), [] )

        State.RenditionProgress event ->
            ( model, Just (Msg.Channel event.channelId (Channel.RenditionProgress event)), [] )

        State.RenditionChange event ->
            ( model, Just (Msg.Channel event.channelId (Channel.RenditionChange event)), [] )

        State.RenditionCreate rendition ->
            let
                msg =
                    Msg.Channel rendition.channelId (Channel.AddRendition rendition)

                notifications =
                    case model.activeChannelId of
                        Nothing ->
                            model.notifications

                        Just id ->
                            if rendition.channelId == id then
                                let
                                    notification =
                                        Notification.forRendition
                                            model.animationTime
                                            rendition
                                in
                                    notification :: model.notifications
                            else
                                model.notifications
            in
                ( { model | notifications = notifications }, Just msg, [] )

        State.RenditionActive channelId renditionId ->
            ( model, Just (Msg.Channel channelId (Channel.RenditionActive renditionId)), [] )


task : Msg -> Cmd Msg
task msg =
    Task.perform identity (Task.succeed msg)


loadChannels : List Channel.State -> List Rendition.State -> List Channel.Model
loadChannels channelStates renditionStates =
    let
        channels =
            List.map (Channel.State.initialState renditionStates) channelStates

        activeChannelId =
            Maybe.map (\channel -> channel.id) (List.head channels)
    in
        channels


loadReceivers : List Receiver.State -> List Receiver.Model
loadReceivers receiverStates =
    List.map Receiver.State.initialState receiverStates
