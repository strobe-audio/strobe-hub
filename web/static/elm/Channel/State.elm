module Channel.State (initialState, update) where


import Effects exposing (Effects, Never)
import Debug

import Types exposing (ChannelState, ReceiverState, BroadcasterState)
import Channel
import Receiver.State


forChannel : String -> List { a | zoneId : String } -> List { a | zoneId : String }
forChannel channelId list =
  List.filter (\r -> r.zoneId == channelId) list


initialState : BroadcasterState -> ChannelState -> Channel.Model
initialState broadcasterState channelState =
    let
        receivers = forChannel channelState.id broadcasterState.receivers
        renditions = forChannel channelState.id broadcasterState.sources
    in
        { id = channelState.id
        , name = channelState.name
        , position = channelState.position
        , volume = channelState.volume
        , playing = channelState.playing
        , receivers = List.map Receiver.State.initialState receivers
        , playlist = renditions
        , showAddReceiver = False
        }


update : Channel.Action -> Channel.Model -> ( Channel.Model, Effects Channel.Action )
update action channel =
  case action of
    Channel.NoOp ->
      ( channel, Effects.none )

    Channel.ShowAddReceiver show ->
      ( { channel | showAddReceiver = show }, Effects.none )

    Channel.Volume volume ->
      ( channel, Effects.none )

    Channel.PlayPause ->
      ( channel, Effects.none )

    Channel.ModifyReceiver receiverAction ->
      ( channel, Effects.none )

    Channel.ModifyRendition renditionId renditionAction ->
      ( channel, Effects.none )




