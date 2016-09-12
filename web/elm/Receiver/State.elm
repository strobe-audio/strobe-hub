module Receiver.State exposing (initialState, update)

import Receiver
import Receiver.Cmd
import Volume
import Msg exposing (Msg)


initialState : Receiver.State -> Receiver.Model
initialState state =
    { id = state.id
    , name = state.name
    , online = state.online
    , volume = state.volume
    , channelId = state.channelId
    , editingName = False
    }


updateVolume : Volume.Msg -> Receiver.Model -> ( Receiver.Model, Cmd Msg )
updateVolume volumeMsg receiver =
    case volumeMsg of
        Volume.Change maybeVol ->
            case maybeVol of
                Nothing ->
                    ( receiver, Cmd.none )

                Just volume ->
                    let
                        updated =
                            { receiver | volume = volume }
                    in
                        ( updated, Receiver.Cmd.volume updated )


update : Receiver.Msg -> Receiver.Model -> ( Receiver.Model, Cmd Msg )
update action model =
    case action of
        Receiver.NoOp ->
            model ! []

        Receiver.Volume volumeMsg ->
            updateVolume volumeMsg model

        -- The volume has been changed by someone else
        Receiver.VolumeChanged volume ->
            { model | volume = volume } ! []

        Receiver.Attach channelId ->
            model ! [ Receiver.Cmd.attach channelId model.id ]

        Receiver.Attached channelId ->
            { model | channelId = channelId } ! []

        Receiver.Online channelId ->
            { model | online = True, channelId = channelId } ! []

        Receiver.Offline ->
            { model | online = False } ! []

        Receiver.Status event channelId ->
            case event of
                "receiver_added" ->
                    update (Receiver.Online channelId) model

                "receiver_removed" ->
                    update Receiver.Offline model

                "reattach_receiver" ->
                    update (Receiver.Attached channelId) model

                _ ->
                    model ! []
