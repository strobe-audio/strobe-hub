module State (initialState, update, activeChannel, attachedReceivers, detachedReceivers, libraryVisible, playlistVisible) where

import Effects exposing (Effects, Never)
import Debug
import Window
import List.Extra
import Root
import Root.Effects
import Channel
import Channel.State
import Channels
import Channels.State
import Receiver
import Receiver.State
import Library.State
import Input.State


initialState : Root.Model
initialState =
  { channels = Channels.State.initialState
  , receivers = []
  , listMode = Root.PlaylistMode
  , mustShowLibrary = False
  , library = Library.State.initialState
  }


broadcasterState : Root.BroadcasterState -> List Channel.Model
broadcasterState state =
  List.map (Channel.State.initialState (Debug.log "state" state)) state.channels


activeChannel : Root.Model -> Maybe Channel.Model
activeChannel model =
  Channels.State.activeChannel model.channels


update : Root.Action -> Root.Model -> ( Root.Model, Effects Root.Action )
update action model =
  case action of
    Root.NoOp ->
      ( model, Effects.none )

    Root.InitialState state ->
      let
        channels =  Channels.State.loadChannels state model.channels

        receivers =
          List.map Receiver.State.initialState state.receivers

        updatedModel =
          { model
            | channels = channels
            , receivers = receivers
          }
      in
        ( updatedModel, Effects.none )

    Root.SetListMode mode ->
      ( { model | listMode = mode }, Effects.none )

    Root.ReceiverStatus ( eventType, event ) ->
      case eventType of
        "receiver_added" ->
          update ((Root.ModifyReceiver event.receiverId) (Receiver.Online event.channelId)) model

        "receiver_removed" ->
          update ((Root.ModifyReceiver event.receiverId) Receiver.Offline) model

        _ ->
          ( model, Effects.none )

    Root.ModifyReceiver receiverId receiverAction ->
      let
        updateReceiver receiver =
          if receiver.id == receiverId then
            let
              ( updatedReceiver, effect ) =
                (Receiver.State.update receiverAction receiver)
            in
              ( updatedReceiver, Effects.map (Root.ModifyReceiver receiver.id) effect )
          else
            ( receiver, Effects.none )

        ( receivers, effects ) =
          (List.map updateReceiver model.receivers) |> List.unzip
      in
        ( { model | receivers = receivers }, (Effects.batch effects) )

    Root.Channels channelsAction ->
      let
          (channelsModel, effect) = Channels.State.update channelsAction model.channels
      in
          ( { model | channels = channelsModel }, Effects.map Root.Channels effect )

    Root.VolumeChange event ->
      case event.target of
        "receiver" ->
          update (Root.ModifyReceiver event.id (Receiver.VolumeChanged event.volume)) model

        "channel" ->
          update (Root.Channels (Channels.VolumeChanged (event.id, event.volume))) model

        _ ->
          ( model, Effects.none )

    Root.Viewport width ->
      let
        mustShowLibrary =
          width > 800
      in
        ( { model | mustShowLibrary = mustShowLibrary }, Effects.none )

    Root.LibraryRegistration node ->
      ( { model | library = Library.State.add model.library node }
      , Effects.none
      )

    Root.Library libraryAction ->
      let
        ( library, effect ) =
          Library.State.update libraryAction model.library model.channels.activeChannelId
      in
        ( { model | library = library }
        , (Effects.map Root.Library effect)
        )

    Root.NewRendition rendition ->
      update (Root.Channels (Channels.AddRendition (rendition.channelId, rendition))) model


attachedReceivers : Root.Model -> Channel.Model -> List Receiver.Model
attachedReceivers model channel =
  List.filter (\r -> r.channelId == channel.id) model.receivers


detachedReceivers : Root.Model -> Channel.Model -> List Receiver.Model
detachedReceivers model channel =
  List.filter (\r -> r.channelId /= channel.id) model.receivers


libraryVisible : Root.Model -> Bool
libraryVisible model =
  case model.mustShowLibrary of
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
  case model.mustShowLibrary of
    True ->
      True

    False ->
      case model.listMode of
        Root.LibraryMode ->
          False

        Root.PlaylistMode ->
          True
