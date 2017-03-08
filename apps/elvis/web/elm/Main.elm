module Main exposing (main)

import Debug
import Html
import Msg exposing (Msg)
import Window
import AnimationFrame
import Root
import Root.State
import Root.View
import Ports
import Navigation
import Routing


main : Program (Maybe Root.SavedState) Root.Model Msg
main =
    Navigation.programWithFlags Msg.UrlChange
        { init = init
        , view = Root.View.root
        , update = Root.State.updateSavingState
        , subscriptions = subscriptions
        }


init : Maybe Root.SavedState -> Navigation.Location -> ( Root.Model, Cmd Msg )
init savedState location =
    let
        currentRoute =
            (Routing.parseLocation location)

        initialState =
            Root.State.initialState

        routeState =
            case currentRoute of
                Routing.ChannelRoute channelId ->
                    { initialState | activeChannelId = Just channelId }

                _ ->
                    initialState

        startingState =
            Root.State.restoreSavedState savedState routeState
    in
        ( startingState, Cmd.none )


subscriptions : Root.Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.broadcasterStateActions
        , Ports.receiverStatusActions
        , Ports.receiverPresenceActions
        , Ports.channelStatusActions
        , Ports.renditionProgressActions
        , Ports.renditionChangeActions
        , Ports.volumeChangeActions
        , Ports.playListAdditionActions
        , Ports.libraryRegistrationActions
        , Ports.libraryResponseActions
        , Ports.windowStartupActions
        , Ports.channelAdditionActions
        , Ports.channelRenameActions
        , Ports.receiverRenameActions
        , Ports.scrollTopActions
        , Ports.connectionStatusActions
        , viewportWidth
        , Ports.animationScrollActions
        , Ports.applicationSettingsActions
        ]


viewportWidth : Sub Msg
viewportWidth =
    Window.resizes (\size -> Msg.BrowserViewport size.width)
