module Channels.State exposing (..)

import Debug
import List.Extra
import Root
import Channels
import Channels.Cmd
import Channel
import Channel.State
import Input
import Input.State


initialState : Channels.Model
initialState =
    { channels = []
    , showChannelSwitcher = False
    , activeChannelId = Nothing
    , showAddChannel = False
    , newChannelInput = Input.State.blank
    }


loadChannels : Root.BroadcasterState -> Channels.Model -> Channels.Model
loadChannels state model =
    let
        channels =
            List.map (Channel.State.initialState state) state.channels

        activeChannelId =
            Maybe.map (\channel -> channel.id) (List.head channels)
    in
        { model | channels = channels, activeChannelId = activeChannelId }


activeChannel : Channels.Model -> Maybe Channel.Model
activeChannel model =
    case model.activeChannelId of
        Nothing ->
            Nothing

        Just id ->
            List.Extra.find (\c -> c.id == id) model.channels


processInputSignal : Maybe Input.Signal -> Channels.Model -> ( Channels.Model, Channels.Msg )
processInputSignal signal model =
    case signal of
        Nothing ->
            ( model, Channels.NoOp )

        Just cmd ->
            case cmd of
                Input.Value value ->
                    ( model, Channels.Add value )

                Input.Close ->
                    ( model, Channels.ToggleAdd )


update : Channels.Msg -> Channels.Model -> ( Channels.Model, Cmd Channels.Msg )
update action model =
    case action of
        Channels.NoOp ->
            ( model, Cmd.none )

        Channels.Modify channelId channelAction ->
            let
                updateChannel channel =
                    if channel.id == channelId then
                        let
                            ( updatedChannel, effect ) =
                                (Channel.State.update channelAction channel)
                        in
                            ( updatedChannel, Cmd.map (Channels.Modify channelId) effect )
                    else
                        ( channel, Cmd.none )

                ( channels, effects ) =
                    (List.map updateChannel model.channels) |> List.unzip
            in
                ( { model | channels = channels }, (Cmd.batch effects) )

        Channels.VolumeChanged ( channelId, volume ) ->
            update (Channels.Modify channelId (Channel.VolumeChanged volume)) model

        Channels.AddRendition ( channelId, rendition ) ->
            update (Channels.Modify channelId (Channel.AddRendition rendition)) model

        -- BEGIN CHANNEL STUFF
        Channels.ToggleSelector ->
            ( { model | showChannelSwitcher = not (model.showChannelSwitcher) }, Cmd.none )

        Channels.ToggleAdd ->
            ( { model | showAddChannel = not model.showAddChannel, newChannelInput = Input.State.blank }, Cmd.none )

        Channels.AddInput inputAction ->
            let
                ( input, inputCmd, signal ) =
                    Input.State.update inputAction model.newChannelInput

                ( model', signalCmds ) =
                    processInputSignal signal { model | newChannelInput = input }

                ( updatedModel, cmd ) =
                    update signalCmds model'
            in
                ( updatedModel, Cmd.batch [ (Cmd.map Channels.AddInput inputCmd), cmd ] )

        Channels.Add name ->
            let
                _ =
                    Debug.log "add channel" name

                model' =
                    { model | newChannelInput = Input.State.blank, showAddChannel = False, showChannelSwitcher = False }
            in
                ( model', Channels.Cmd.addChannel name )

        Channels.Added channelState ->
            let
                channel =
                    Channel.State.newChannel channelState

                model' =
                    { model | channels = channel :: model.channels }
            in
                update (Channels.Choose channel) model'

        Channels.Choose channel ->
            let
                updatedModel =
                    { model
                        | showChannelSwitcher = True
                        , showAddChannel = False
                        , activeChannelId = Just channel.id
                    }
            in
                ( updatedModel, Cmd.none )
