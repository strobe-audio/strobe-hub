module Receiver.State exposing (initialState, update)

import Debug


--

import Receiver
import Receiver.Cmd
import Volume
import Msg exposing (Msg)
import Input
import Input.State
import Utils.Touch


initialState : Receiver.State -> Receiver.Model
initialState state =
    { id = state.id
    , name = state.name
    , online = state.online
    , volume = state.volume
    , channelId = state.channelId
    , editName = False
    , editNameInput = Input.State.blank
    , touches = Utils.Touch.null
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

        Receiver.ShowEditName state ->
            let
                editNameInput =
                    case state of
                        True ->
                            Input.State.withValue model.editNameInput model.name

                        False ->
                            Input.State.clear model.editNameInput
            in
                { model | editName = state, editNameInput = editNameInput } ! []

        Receiver.EditName inputMsg ->
            let
                ( input, inputCmd, action ) =
                    Input.State.update inputMsg model.editNameInput

                ( model_, actionMsg ) =
                    (processInputAction action { model | editNameInput = input })

                ( updatedModel, cmd ) =
                    update actionMsg model_
            in
                ( updatedModel, Cmd.batch [ (Cmd.map (\m -> (Msg.Receiver model.id) (Receiver.EditName m)) inputCmd), cmd ] )

        Receiver.Renamed newName ->
            { model | name = newName, editName = False } ! []

        Receiver.Rename newName ->
            let
                model_ =
                    { model | name = newName }
            in
                model_ ! [ Receiver.Cmd.rename model_ ]

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
        Receiver.SingleTouch te ->
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
                updated ! [cmd]


processInputAction : Maybe Input.Action -> Receiver.Model -> ( Receiver.Model, Receiver.Msg )
processInputAction action model =
    case action of
        Nothing ->
            ( model, Receiver.NoOp )

        Just msg ->
            case msg of
                Input.Value value ->
                    ( model, Receiver.Rename value )

                Input.Close ->
                    ( model, Receiver.ShowEditName False )
