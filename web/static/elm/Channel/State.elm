module Channel.State (initialState, update) where


import Effects exposing (Effects, Never)
import Debug

import Types exposing (ChannelState, ReceiverState, BroadcasterState)
import Channel.Types exposing (..)
import Receiver.State


forChannel : String -> List { a | zoneId : String } -> List { a | zoneId : String }
forChannel channelId list =
  List.filter (\r -> r.zoneId == channelId) list


initialState : BroadcasterState -> ChannelState -> Channel
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


update : ChannelAction -> Channel -> ( Channel, Effects ChannelAction )
update action channel =
  case action of
    NoOp ->
      ( channel, Effects.none )

    ShowAddReceiver show ->
      ( { channel | showAddReceiver = show }, Effects.none )

    Volume volume ->
      ( channel, Effects.none )

    PlayPause ->
      ( channel, Effects.none )

    Receiver receiverAction ->
      ( channel, Effects.none )

    ModifyRendition renditionId renditionAction ->
      ( channel, Effects.none )




