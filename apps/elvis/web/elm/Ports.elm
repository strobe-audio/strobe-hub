port module Ports exposing (..)

import Channel
import ID
import Library
import Rendition
import Msg exposing (Msg)
import Root
import State
import Receiver
import Time
import Settings
import Json.Decode
import Decoders


decodeEvent : Json.Decode.Value -> Msg
decodeEvent =
    (Json.Decode.decodeValue Decoders.typedMessageDecoder) >> Msg.Event



-- Incoming JS -> Elm


port broadcasterEvent : (Json.Decode.Value -> msg) -> Sub msg


broadcasterEventSubscription : Sub Msg
broadcasterEventSubscription =
    broadcasterEvent decodeEvent


port connectionStatus : (Bool -> m) -> Sub m


connectionStatusActions =
    connectionStatus Msg.Connected


port windowWidth : (Int -> m) -> Sub m


windowStartupActions =
    windowWidth Msg.BrowserViewport


port scrollTop : (Int -> m) -> Sub m


scrollTopActions =
    scrollTop Msg.BrowserScroll


port libraryRegistration : (Library.Section -> m) -> Sub m


libraryRegistrationActions : Sub Msg
libraryRegistrationActions =
    libraryRegistration Msg.BroadcasterLibraryRegistration


port libraryResponse : (Library.FolderResponse -> m) -> Sub m


libraryResponseActions : Sub Msg
libraryResponseActions =
    let
        translate : Library.FolderResponse -> Msg
        translate response =
            Msg.Library (Library.Response response.url response.folder)
    in
        libraryResponse translate


port animationScroll : (( Time.Time, Maybe Float, Float ) -> m) -> Sub m


animationScrollActions : Sub Msg
animationScrollActions =
    animationScroll Msg.AnimationScroll


port applicationSettings : (( String, Settings.Model ) -> m) -> Sub m


applicationSettingsActions : Sub Msg
applicationSettingsActions =
    let
        translate : ( String, Settings.Model ) -> Msg
        translate ( app, settings ) =
            Msg.LoadApplicationSettings app settings
    in
        applicationSettings translate


port forcePress : (Bool -> msg) -> Sub msg


forcePressSubscription =
    forcePress Msg.ForcePress



-- Outgoing Elm -> JS


port saveState : Root.SavedState -> Cmd msg


port volumeChangeRequests : ( String, Bool, String, String, Float ) -> Cmd msg


port receiverMuteRequests : ( String, Bool ) -> Cmd msg


port playPauseChanges : ( String, Bool ) -> Cmd msg


port channelNameChanges : ( ID.Channel, String ) -> Cmd msg


port receiverNameChanges : ( ID.Receiver, String ) -> Cmd msg


port channelClearPlaylist : ID.Channel -> Cmd msg


port playlistSkipRequests : ( String, String ) -> Cmd msg


port playlistRemoveRequests : ( String, String ) -> Cmd msg


port addChannelRequests : String -> Cmd msg


port removeChannelRequests : ID.Channel -> Cmd msg


port attachReceiverRequests : ( String, String ) -> Cmd msg


port libraryRequests : ( String, String, Maybe String ) -> Cmd msg


port blurActiveElement : Bool -> Cmd msg


port settingsRequests : String -> Cmd msg


port settingsSave : Settings.Model -> Cmd msg
