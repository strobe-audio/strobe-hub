module Main (main) where

import Effects exposing (Effects, Never)
import Html exposing (Html)
import Task exposing (Task)
import Window
import StartApp
import Channel
import Channel.Signals
import Channels
import Channels.Signals
import ID
import Library
import Library.Signals
import Receiver.Signals
import Receivers
import Rendition
import Rendition.Signals
import Root
import Root.State
import Root.View
import Volume.Signals


app : StartApp.App Root.Model
app =
  StartApp.start
    { init = ( Root.State.initialState, Effects.none )
    , update = Root.State.update
    , view = Root.View.root
    , inputs =
        [ broadcasterStateActions
        , receiverStatusActions
        , channelStatusActions
        , sourceProgressActions
        , sourceChangeActions
        , volumeChangeActions
        , playListAdditionActions
        , libraryRegistrationActions
        , libraryResponseActions
        , viewportWidth
        , windowStartupActions
        , channelAdditionActions
        , channelRenameActions
        ]
    }


main : Signal Html
main =
  app.html


viewportWidth : Signal Root.Action
viewportWidth =
  Signal.map Root.Viewport Window.width


port windowWidth : Signal Int
windowStartupActions : Signal Root.Action
windowStartupActions =
  Signal.map Root.Viewport windowWidth


port tasks : Signal (Task Never ())
port tasks =
  app.tasks


port broadcasterState : Signal Root.BroadcasterState
broadcasterStateActions : Signal Root.Action
broadcasterStateActions =
  Signal.map Root.InitialState broadcasterState


port receiverStatus : Signal ( String, Root.ReceiverStatusEvent )
receiverStatusActions : Signal Root.Action
receiverStatusActions =
  let
    forward ( event, status ) =
      Root.Receivers (Receivers.Status event status.receiverId status.channelId)
  in
    Signal.map forward receiverStatus


port channelStatus : Signal ( String, Root.ChannelStatusEvent )
channelStatusActions : Signal Root.Action
channelStatusActions =
  let
    forward ( eventName, event ) =
      let
        _ =
          Debug.log "channelStatusActions" ( eventName, event )
      in
        Root.Channels ((Channels.Modify event.channelId) (Channel.Status ( eventName, event.status )))
  in
    Signal.map forward channelStatus


port sourceProgress : Signal Rendition.ProgressEvent
sourceProgressActions : Signal Root.Action
sourceProgressActions =
  let
    forward event =
      Root.Channels ((Channels.Modify event.channelId) (Channel.RenditionProgress event))
  in
    Signal.map forward sourceProgress


port sourceChange : Signal Rendition.ChangeEvent
sourceChangeActions : Signal Root.Action
sourceChangeActions =
  let
    forward event =
      Root.Channels ((Channels.Modify event.channelId) (Channel.RenditionChange event))
  in
    Signal.map forward sourceChange


port volumeChange : Signal Root.VolumeChangeEvent
volumeChangeActions : Signal Root.Action
volumeChangeActions =
  Signal.map Root.VolumeChange volumeChange


port playlistAddition : Signal Root.PlaylistEntry
playListAdditionActions : Signal Root.Action
playListAdditionActions =
  Signal.map Root.NewRendition playlistAddition


port libraryRegistration : Signal Library.Node
libraryRegistrationActions : Signal Root.Action
libraryRegistrationActions =
  Signal.map Root.LibraryRegistration libraryRegistration


port volumeChangeRequests : Signal ( String, String, Float )
port volumeChangeRequests =
  let
    mailbox =
      Volume.Signals.volumeChange
  in
    mailbox.signal


port playPauseChanges : Signal ( String, Bool )
port playPauseChanges =
  let
    mailbox =
      Channel.Signals.playPause
  in
    mailbox.signal


port channelNameChanges : Signal ( ID.Channel, String )
port channelNameChanges =
  let
    mailbox =
      Channel.Signals.rename
  in
    mailbox.signal


port playlistSkipRequests : Signal ( String, String )
port playlistSkipRequests =
  let
    mailbox =
      Rendition.Signals.skip
  in
    mailbox.signal


port addChannelRequests : Signal String
port addChannelRequests =
  let
    mailbox =
      Channels.Signals.addChannel
  in
    mailbox.signal


port attachReceiverRequests : Signal ( String, String )
port attachReceiverRequests =
  let
    mailbox =
      Receiver.Signals.attach
  in
    mailbox.signal


port libraryRequests : Signal ( String, String )
port libraryRequests =
  let
    mailbox =
      Library.Signals.requests
  in
    mailbox.signal


port libraryResponse : Signal Library.FolderResponse
libraryResponseActions : Signal Root.Action
libraryResponseActions =
  let
    translate response =
      -- log ("Translate " ++ toString(response.folder))
      Root.Library (Library.Response response.folder)
  in
    Signal.map translate libraryResponse


port channelAdditions : Signal Channel.State
channelAdditionActions =
  let
    translate state =
      Root.Channels (Channels.Added state)
  in
    Signal.map translate channelAdditions


port channelRenames : Signal ( ID.Channel, String )
channelRenameActions =
  let
    translate ( channelId, name ) =
      Root.Channels ((Channels.Modify channelId) (Channel.Renamed name))
  in
    Signal.map translate channelRenames
