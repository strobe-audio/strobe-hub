module Channel.State exposing (initialState, update, newChannel)

import Debug
import Root exposing (BroadcasterState)
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


forChannel : String -> List { a | channelId : String } -> List { a | channelId : String }
forChannel channelId list =
    List.filter (\r -> r.channelId == channelId) list


initialState : BroadcasterState -> Channel.State -> Channel.Model
initialState broadcasterState channelState =
    let
        renditions =
            forChannel channelState.id broadcasterState.sources

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
    , editNameInput = Input.State.blank
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

        -- case maybeVolume of
        --   Just volume ->
        --     let
        --       updatedChannel =
        --         { channel | volume = volume }
        --     in
        --       ( updatedChannel, Channel.Cmd.volume updatedChannel )
        --
        --   Nothing ->
        --     ( channel, Cmd.none )
        -- The volume has been changed by someone else
        Channel.VolumeChanged volume ->
            ( { channel | volume = volume }, Cmd.none )

        Channel.Status ( event, status ) ->
            let
                channel' =
                    case event of
                        "channel_play_pause" ->
                            case status of
                                "play" ->
                                    { channel | playing = True }

                                _ ->
                                    { channel | playing = False }

                        _ ->
                            channel
            in
                ( channel', Cmd.none )

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
            update (Channel.ModifyRendition event.sourceId (Rendition.Progress event))
                channel

        Channel.RenditionChange event ->
            let
                isMember =
                    (\r -> (List.member r.id event.removeSourceIds))

                playlist =
                    List.filter (isMember >> not) channel.playlist

                updatedChannel =
                    { channel | playlist = playlist }
            in
                ( updatedChannel, Cmd.none )

        Channel.AddRendition rendition ->
            let
                before =
                    List.take rendition.position channel.playlist

                after =
                    rendition :: (List.drop rendition.position channel.playlist)

                playlist =
                    List.concat [ before, after ]
            in
                ( { channel | playlist = playlist }, Cmd.none )

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

                ( channel', actionMsg ) =
                    (processInputAction action { channel | editNameInput = input })

                ( updatedChannel, cmd ) =
                    update actionMsg channel'
            in
                ( updatedChannel, Cmd.batch [ (Cmd.map (\m -> (Msg.Channel channel.id) (Channel.EditName m)) inputCmd), cmd ] )

        Channel.Rename name ->
            let
                channel' =
                    { channel | name = name, editName = False }
            in
                ( channel', Channel.Cmd.rename channel' )

        Channel.Renamed name ->
            let
                channel' =
                    { channel | name = name, originalName = name }
            in
                ( channel', Cmd.none )

        Channel.ClearPlaylist ->
            let
                channel' =
                    { channel | playlist = [] }
            in
                ( channel', Channel.Cmd.clearPlaylist channel' )


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
