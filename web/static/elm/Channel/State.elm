module Channel.State (initialState, update, attachedReceivers, detachedReceivers) where


import Effects exposing (Effects, Never)
import Debug

import Root exposing (ChannelState, ReceiverState, BroadcasterState)
import Channel
import Receiver
import Receiver.State


forChannel : String -> List { a | zoneId : String } -> List { a | zoneId : String }
forChannel channelId list =
  List.filter (\r -> r.zoneId == channelId) list


initialState : BroadcasterState -> ChannelState -> Channel.Model
initialState broadcasterState channelState =
    let
        renditions = forChannel channelState.id broadcasterState.sources
    in
        { id = channelState.id
        , name = channelState.name
        , position = channelState.position
        , volume = channelState.volume
        , playing = channelState.playing
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




attachedReceivers : Root.Model -> Channel.Model -> List Receiver.Model
attachedReceivers model channel =
  List.filter (\r -> r.zoneId == channel.id) model.receivers


detachedReceivers : Root.Model -> Channel.Model -> List Receiver.Model
detachedReceivers model channel =
  List.filter (\r -> r.zoneId /= channel.id) model.receivers

