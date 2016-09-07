port module Ports exposing (..)


import Channel
import Channels
import ID
import Library
import Receivers
import Rendition
import Msg exposing (Msg)
import Root

 -- Incoming JS -> Elm

port windowWidth : (Int -> m) -> Sub m
windowStartupActions =
  windowWidth Msg.Viewport


port scrollTop : (Int -> m) -> Sub m
scrollTopActions =
  scrollTop Msg.Scroll


port broadcasterState : (Root.BroadcasterState -> m) -> Sub m

broadcasterStateActions : Sub Msg
broadcasterStateActions =
  broadcasterState Msg.InitialState


port receiverStatus : (( String, Root.ReceiverStatusEvent ) -> m) -> Sub m

receiverStatusActions : Sub Msg
receiverStatusActions =
  let
      forward ( event, status ) =
        Msg.Receivers (Receivers.Status event status.receiverId status.channelId)
  in
      receiverStatus forward


port channelStatus : (( String, Root.ChannelStatusEvent ) -> m) -> Sub m

channelStatusActions : Sub Msg
channelStatusActions =
  let
      forward ( eventName, event ) =
        Msg.Channels ((Channels.Modify event.channelId) (Channel.Status ( eventName, event.status )))
  in
      channelStatus forward


port sourceProgress : (Rendition.ProgressEvent -> m) -> Sub m

sourceProgressActions : Sub Msg
sourceProgressActions =
  let
      forward event =
        Msg.Channels ((Channels.Modify event.channelId) (Channel.RenditionProgress event))
  in
      sourceProgress forward


port sourceChange : (Rendition.ChangeEvent -> m) -> Sub m

sourceChangeActions : Sub Msg
sourceChangeActions =
  let
      forward event =
        Msg.Channels ((Channels.Modify event.channelId) (Channel.RenditionChange event))
  in
      sourceChange forward


port volumeChange : (Root.VolumeChangeEvent -> m) -> Sub m

volumeChangeActions : Sub Msg
volumeChangeActions =
  volumeChange Msg.VolumeChange


port playlistAddition : (Rendition.Model -> m) -> Sub m

playListAdditionActions : Sub Msg
playListAdditionActions =
  playlistAddition Msg.NewRendition


port libraryRegistration : (Library.Node -> m) -> Sub m

libraryRegistrationActions : Sub Msg
libraryRegistrationActions =
  libraryRegistration Msg.LibraryRegistration


port libraryResponse : (Library.FolderResponse -> m) -> Sub m

libraryResponseActions : Sub Msg
libraryResponseActions =
  let
      translate response =
        Msg.Library (Library.Response response.folder)
  in
      libraryResponse translate


port channelAdditions : (Channel.State -> m) -> Sub m
channelAdditionActions : Sub Msg
channelAdditionActions =
  let
      translate state =
        Msg.Channels (Channels.Added state)
  in
      channelAdditions translate


port channelRenames : (( ID.Channel, String ) -> m) -> Sub m
channelRenameActions : Sub Msg
channelRenameActions =
  let
      translate ( channelId, name ) =
        Msg.Channels ((Channels.Modify channelId) (Channel.Renamed name))
  in
      channelRenames translate


 -- Outgoing Elm -> JS

port volumeChangeRequests : ( String, String, Float ) -> Cmd msg

port playPauseChanges : ( String, Bool ) -> Cmd msg

port channelNameChanges : ( ID.Channel, String ) -> Cmd msg

port channelClearPlaylist : ID.Channel -> Cmd msg

port playlistSkipRequests : ( String, String ) -> Cmd msg

port addChannelRequests : String -> Cmd msg

port attachReceiverRequests : (String, String) -> Cmd msg

port libraryRequests : ( String, String ) -> Cmd msg

