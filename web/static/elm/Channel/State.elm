module Channel.State (initialState, update, newChannel) where

import Effects exposing (Effects, Never)
import Debug
import Root exposing (ChannelState, ReceiverState, BroadcasterState)
import Channel
import Channel.Effects
import Receiver
import Receiver.State
import Rendition
import Rendition.State


forChannel : String -> List { a | channelId : String } -> List { a | channelId : String }
forChannel channelId list =
  List.filter (\r -> r.channelId == channelId) list


initialState : BroadcasterState -> ChannelState -> Channel.Model
initialState broadcasterState channelState =
  let
    renditions =
      forChannel channelState.id broadcasterState.sources

    model =
      newChannel channelState
  in
    { model | playlist = renditions }


newChannel : ChannelState -> Channel.Model
newChannel channelState =
  { id = channelState.id
  , name = channelState.name
  , position = channelState.position
  , volume = channelState.volume
  , playing = channelState.playing
  , playlist = []
  , showAddReceiver = False
  }


update : Channel.Action -> Channel.Model -> ( Channel.Model, Effects Channel.Action )
update action channel =
  case action of
    Channel.NoOp ->
      ( channel, Effects.none )

    Channel.ShowAddReceiver show ->
      ( { channel | showAddReceiver = show }, Effects.none )

    Channel.Volume maybeVolume ->
      case maybeVolume of
        Just volume ->
          let
            updatedChannel =
              { channel | volume = volume }
          in
            ( updatedChannel, Channel.Effects.volume updatedChannel )

        Nothing ->
          ( channel, Effects.none )

    -- The volume has been changed by someone else
    Channel.VolumeChanged volume ->
      ( { channel | volume = volume }, Effects.none )

    Channel.PlayPause ->
      let
        updatedChannel =
          channelPlayPause channel
      in
        ( updatedChannel, Channel.Effects.playPause updatedChannel )

    Channel.ModifyRendition renditionId renditionAction ->
      let
        updateRendition rendition =
          if rendition.id == renditionId then
            let
              ( updatedRendition, effect ) =
                Rendition.State.update renditionAction rendition
            in
              ( updatedRendition, Effects.map (Channel.ModifyRendition rendition.id) effect )
          else
            ( rendition, Effects.none )

        ( renditions, effects ) =
          (List.map updateRendition channel.playlist)
            |> List.unzip
      in
        ( { channel | playlist = renditions }, Effects.batch effects )

    Channel.RenditionProgress event ->
      update
        (Channel.ModifyRendition event.sourceId (Rendition.Progress event))
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
        ( updatedChannel, Effects.none )

    Channel.AddRendition rendition ->
      let
        before =
          List.take rendition.position channel.playlist

        after =
          rendition :: (List.drop rendition.position channel.playlist)

        playlist =
          List.concat [ before, after ]
      in
        ( { channel | playlist = playlist }, Effects.none )


channelPlayPause : Channel.Model -> Channel.Model
channelPlayPause channel =
  { channel | playing = (not channel.playing) }
