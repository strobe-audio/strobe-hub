module Channel.State exposing (initialState, update, newChannel)

import Debug
import State exposing (BroadcasterState)
import Msg exposing (Msg)
import Channel
import Channel.Cmd
import Receiver
import Receiver.State
import Rendition
import Rendition.State
import Input
import Input.State
import Volume
import Utils.Touch
import List.Extra


forChannel : String -> List { a | channelId : String } -> List { a | channelId : String }
forChannel channelId list =
    List.filter (\r -> r.channelId == channelId) list


initialState : BroadcasterState -> Channel.State -> Channel.Model
initialState broadcasterState channelState =
    let
        renditions =
            (List.map Rendition.State.initialState (forChannel channelState.id broadcasterState.renditions))

        model =
            newChannel channelState
    in
        { model | playlist = renditions }


newChannel : Channel.State -> Channel.Model
newChannel channelState =
    { id = channelState.id
    , name = channelState.name
    , originalName = channelState.name
    , position = channelState.position
    , volume = channelState.volume
    , playing = channelState.playing
    , playlist = []
    , showAddReceiver = False
    , editName = False
    , confirmDelete = False
    , removalInProgress = False
    , editNameInput = Input.State.blank
    , touches = Utils.Touch.null
    }


update : Channel.Msg -> Channel.Model -> ( Channel.Model, Cmd Msg )
update action channel =
    case action of
        Channel.NoOp ->
            ( channel, Cmd.none )

        Channel.ShowAddReceiver show ->
            ( { channel | showAddReceiver = show }, Cmd.none )

        Channel.Volume volumeMsg ->
            updateVolume volumeMsg channel

        -- The volume has been changed by someone else
        Channel.VolumeChanged volume ->
            ( { channel | volume = volume }, Cmd.none )

        Channel.IsPlaying playing ->
            { channel | playing = playing } ! []

        Channel.PlayPause ->
            let
                updatedChannel =
                    channelPlayPause channel
            in
                ( updatedChannel, Channel.Cmd.playPause updatedChannel )

        Channel.ModifyRendition renditionId renditionAction ->
            let
                updateRendition rendition =
                    if rendition.id == renditionId then
                        let
                            ( updatedRendition, effect ) =
                                Rendition.State.update renditionAction rendition
                        in
                            ( updatedRendition, Cmd.map (\m -> (Msg.Channel channel.id) (Channel.ModifyRendition rendition.id m)) effect )
                    else
                        ( rendition, Cmd.none )

                ( renditions, effects ) =
                    (List.map updateRendition channel.playlist)
                        |> List.unzip
            in
                ( { channel | playlist = renditions }, Cmd.batch effects )

        Channel.RenditionProgress event ->
            update (Channel.ModifyRendition event.renditionId (Rendition.Progress event))
                channel

        Channel.RenditionChange event ->
            let
                isMember =
                    (\r -> (List.member r.id event.removeRenditionIds))

                activateRendition activateId r =
                    { r | active = (r.id == activateId) }

                activate playlist =
                    case event.activateRenditionId of
                        Nothing ->
                            playlist

                        Just id ->
                            List.map (activateRendition id) playlist

                playlist =
                    List.filter (isMember >> not) channel.playlist
                        |> activate

                updatedChannel =
                    { channel | playlist = playlist }
            in
                ( updatedChannel, Cmd.none )

        Channel.AddRendition renditionState ->
            let
                rendition =
                    Rendition.State.initialState renditionState

                ( before, after ) =
                    List.Extra.break (\r -> r.id == renditionState.nextId) channel.playlist

                playlist =
                    List.concat [ before, [ rendition ], after ]
            in
                ( { channel | playlist = playlist }, Cmd.none )

        Channel.RenditionActive renditionId ->
            channel ! []

        Channel.ShowEditName state ->
            let
                editNameInput =
                    case state of
                        True ->
                            Input.State.withValue channel.editNameInput channel.name

                        False ->
                            Input.State.clear channel.editNameInput
            in
                ( { channel | editName = state, editNameInput = editNameInput }, Cmd.none )

        Channel.EditName inputMsg ->
            let
                ( input, inputCmd, action ) =
                    Input.State.update inputMsg channel.editNameInput

                ( channel_, actionMsg ) =
                    (processInputAction action { channel | editNameInput = input })

                ( updatedChannel, cmd ) =
                    update actionMsg channel_
            in
                ( updatedChannel, Cmd.batch [ (Cmd.map (\m -> (Msg.Channel channel.id) (Channel.EditName m)) inputCmd), cmd ] )

        Channel.Rename name ->
            let
                channel_ =
                    { channel | name = name, editName = False }
            in
                ( channel_, Channel.Cmd.rename channel_ )

        Channel.Renamed name ->
            let
                channel_ =
                    { channel | name = name, originalName = name }
            in
                ( channel_, Cmd.none )

        Channel.ClearPlaylist ->
            ( channel, Channel.Cmd.clearPlaylist channel )

        Channel.Tap te ->
            let
                touches =
                    Utils.Touch.update te channel.touches

                ( updated, cmd ) =
                    case Utils.Touch.testEvent te touches of
                        Just (Utils.Touch.Tap msg) ->
                            update msg { channel | touches = Utils.Touch.null }

                        _ ->
                            { channel | touches = touches } ! []
            in
                updated ! [ cmd ]

        Channel.ShowConfirmDelete show ->
            { channel | confirmDelete = show } ! []

        Channel.Remove ->
            { channel | removalInProgress = True } ! [ Channel.Cmd.remove channel.id ]


updateVolume : Volume.Msg -> Channel.Model -> ( Channel.Model, Cmd Msg )
updateVolume volumeMsg channel =
    case volumeMsg of
        Volume.Change maybeVolume ->
            case maybeVolume of
                Just volume ->
                    let
                        updatedChannel =
                            { channel | volume = volume }
                    in
                        ( updatedChannel, Channel.Cmd.volume updatedChannel )

                Nothing ->
                    channel ! []

        Volume.ToggleMute ->
            channel ! []


processInputAction : Maybe Input.Action -> Channel.Model -> ( Channel.Model, Channel.Msg )
processInputAction action model =
    case action of
        Nothing ->
            ( model, Channel.NoOp )

        Just msg ->
            case msg of
                Input.Value value ->
                    ( model, Channel.Rename value )

                Input.Close ->
                    ( model, Channel.ShowEditName False )


channelPlayPause : Channel.Model -> Channel.Model
channelPlayPause channel =
    { channel | playing = (not channel.playing) }
