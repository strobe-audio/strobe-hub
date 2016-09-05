module Root.State exposing (initialState, update, activeChannel, libraryVisible, playlistVisible)

import Debug
import Window
import List.Extra
import Root
import Root.Cmd
import Channel
import Channel.State
import Channels
import Channels.State
import Receiver
import Receiver.State
import Receivers
import Receivers.State
import Library.State
import Input.State


initialState : Root.Model
initialState =
  { channels = Channels.State.initialState
  , receivers = Receivers.State.initialState
  , listMode = Root.PlaylistMode
  , showPlaylistAndLibrary = False
  , library = Library.State.initialState
  }


broadcasterState : Root.BroadcasterState -> List Channel.Model
broadcasterState state =
  List.map (Channel.State.initialState (Debug.log "state" state)) state.channels


activeChannel : Root.Model -> Maybe Channel.Model
activeChannel model =
  Channels.State.activeChannel model.channels


update : Root.Msg -> Root.Model -> ( Root.Model, Cmd Root.Msg )
update action model =
  case action of
    Root.NoOp ->
      ( model, Cmd.none )

    Root.InitialState state ->
      let
        channels =
          Channels.State.loadChannels state model.channels

        receivers =
          Receivers.State.loadReceivers state model.receivers

        -- List.map Receiver.State.initialState state.receivers
        updatedModel =
          { model
            | channels = channels
            , receivers = receivers
          }
      in
        ( updatedModel, Cmd.none )

    Root.Receivers receiversAction ->
      let
        ( receiversModel, effect ) =
          Receivers.State.update receiversAction model.receivers
      in
        ( { model | receivers = receiversModel }, Cmd.map Root.Receivers effect )

    Root.Channels channelsAction ->
      let
        ( channelsModel, effect ) =
          Channels.State.update channelsAction model.channels
      in
        ( { model | channels = channelsModel }, Cmd.map Root.Channels effect )

    Root.VolumeChange event ->
      case event.target of
        "receiver" ->
          update (Root.Receivers (Receivers.VolumeChanged ( event.id, event.volume ))) model

        "channel" ->
          update (Root.Channels (Channels.VolumeChanged ( event.id, event.volume ))) model

        _ ->
          ( model, Cmd.none )

    Root.SetListMode mode ->
      ( { model | listMode = mode }, Cmd.none )

    Root.Viewport width ->
      let
        showPlaylistAndLibrary =
          width > 800
      in
        ( { model | showPlaylistAndLibrary = showPlaylistAndLibrary }, Cmd.none )

    Root.LibraryRegistration node ->
      ( { model | library = Library.State.add model.library node }
      , Cmd.none
      )

    Root.Library libraryAction ->
      let
        ( library, effect ) =
          Library.State.update libraryAction model.library model.channels.activeChannelId
      in
        ( { model | library = library }
        , (Cmd.map Root.Library effect)
        )

    Root.NewRendition rendition ->
      update (Root.Channels (Channels.AddRendition ( rendition.channelId, rendition ))) model

    Root.Scroll value ->
      -- let
          -- _ = Debug.log "scroll" value
      -- in
        ( model, Cmd.none )


libraryVisible : Root.Model -> Bool
libraryVisible model =
  case model.showPlaylistAndLibrary of
    True ->
      True

    False ->
      case model.listMode of
        Root.LibraryMode ->
          True

        Root.PlaylistMode ->
          False


playlistVisible : Root.Model -> Bool
playlistVisible model =
  case model.showPlaylistAndLibrary of
    True ->
      True

    False ->
      case model.listMode of
        Root.LibraryMode ->
          False

        Root.PlaylistMode ->
          True
