module Channels.State (..) where

import Debug
import Effects exposing (Effects, Never)
import List.Extra
import Root
import Channels
import Channels.Effects
import Channel
import Channel.State
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


update : Channels.Action -> Channels.Model -> ( Channels.Model, Effects Channels.Action )
update action model =
  case action of
    Channels.NoOp ->
      ( model, Effects.none )

    Channels.Modify channelId channelAction ->
      let
        updateChannel channel =
          if channel.id == channelId then
            let
              ( updatedChannel, effect ) =
                (Channel.State.update channelAction channel)
            in
              ( updatedChannel, Effects.map (Channels.Modify channelId) effect )
          else
            ( channel, Effects.none )

        ( channels, effects ) =
          (List.map updateChannel model.channels) |> List.unzip
      in
        ( { model | channels = channels }, (Effects.batch effects) )

    Channels.VolumeChanged ( channelId, volume ) ->
      update (Channels.Modify channelId (Channel.VolumeChanged volume)) model

    Channels.AddRendition ( channelId, rendition ) ->
      update (Channels.Modify channelId (Channel.AddRendition rendition)) model

    -- BEGIN CHANNEL STUFF
    Channels.ToggleSelector ->
      ( { model | showChannelSwitcher = not (model.showChannelSwitcher) }, Effects.none )

    Channels.ToggleAdd ->
      ( { model | showAddChannel = not model.showAddChannel, newChannelInput = Input.State.blank }, Effects.none )

    Channels.NewInput inputAction ->
      let
        ( input, effect ) =
          Input.State.update inputAction model.newChannelInput
      in
        ( { model | newChannelInput = input }, (Effects.map Channels.NewInput effect) )

    Channels.Add name ->
      let
        _ =
          Debug.log "add channel" name

        model' =
          { model | newChannelInput = Input.State.blank, showAddChannel = False, showChannelSwitcher = False }
      in
        ( model', Channels.Effects.addChannel name )

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
        ( updatedModel, Effects.none )
