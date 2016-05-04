module State (initialState, update, activeChannel, attachedReceivers, detachedReceivers, libraryVisible, playlistVisible) where

import Effects exposing (Effects, Never)
import Debug
import List.Extra
import Root
import Channel
import Channel.State
import Receiver
import Receiver.State
import Library.State
import Window


initialState : Root.Model
initialState =
  let
    model =
      { channels = []
      , receivers = []
      , showChannelSwitcher = False
      , activeChannelId = Nothing
      , listMode = Root.PlaylistMode
      , mustShowLibrary = False
      , library = Library.State.initialState
      }

    -- , ui = initUIState [] []
    -- , activeState = "channel"
    -- }
  in
    model


broadcasterState : Root.BroadcasterState -> List Channel.Model
broadcasterState state =
  List.map (Channel.State.initialState (Debug.log "state" state)) state.channels


activeChannel : Root.Model -> Maybe Channel.Model
activeChannel model =
  case model.activeChannelId of
    Nothing ->
      Nothing

    Just id ->
      List.Extra.find (\c -> c.id == id) model.channels


update : Root.Action -> Root.Model -> ( Root.Model, Effects Root.Action )
update action model =
  case action of
    Root.NoOp ->
      ( model, Effects.none )

    Root.InitialState state ->
      let
        channels =
          List.map (Channel.State.initialState state) state.channels

        receivers =
          List.map Receiver.State.initialState state.receivers

        activeChannelId =
          Maybe.map (\channel -> channel.id) (List.head channels)

        updatedModel =
          { model
            | channels = channels
            , receivers = receivers
            , activeChannelId = activeChannelId
          }
      in
        ( updatedModel, Effects.none )

    Root.ReceiverStatus ( eventType, event ) ->
      case eventType of
        "receiver_added" ->
          update ((Root.ModifyReceiver event.receiverId) (Receiver.Online event.channelId)) model

        "receiver_removed" ->
          update ((Root.ModifyReceiver event.receiverId) Receiver.Offline) model

        _ ->
          ( model, Effects.none )

    Root.ModifyChannel channelId channelAction ->
      let
        updateChannel channel =
          if channel.id == channelId then
            let
              ( updatedChannel, effect ) =
                (Channel.State.update channelAction channel)
            in
              ( updatedChannel, Effects.map (Root.ModifyChannel channelId) effect )
          else
            ( channel, Effects.none )

        ( channels, effects ) =
          (List.map updateChannel model.channels) |> List.unzip
      in
        ( { model | channels = channels }, (Effects.batch effects) )

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

    Root.SetListMode mode ->
      ( { model | listMode = mode }, Effects.none )

    Root.ToggleChannelSelector ->
      ( { model | showChannelSwitcher = not (model.showChannelSwitcher) }, Effects.none )

    Root.ChooseChannel channel ->
      let
        updatedModel =
          { model
            | showChannelSwitcher = False
            , activeChannelId = Just channel.id
          }
      in
        ( updatedModel, Effects.none )

    Root.VolumeChange event ->
      case event.target of
        "receiver" ->
          update (Root.ModifyReceiver event.id (Receiver.VolumeChanged event.volume)) model

        "channel" ->
          update (Root.ModifyChannel event.id (Channel.VolumeChanged event.volume)) model

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
        -- _ =
        --   Debug.log "library" libraryAction
        ( library, effect ) =
          Library.State.update libraryAction model.library model.activeChannelId
      in
        ( { model | library = library }
        , (Effects.map Root.Library effect)
        )

    Root.NewRendition rendition ->
      update (Root.ModifyChannel rendition.channelId (Channel.AddRendition rendition)) model


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
