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


main : Program Root.Startup Root.Model Msg
main =
    Navigation.programWithFlags Msg.UrlChange
        { init = init
        , view = Root.View.root
        , update = Root.State.updateSavingState
        , subscriptions = subscriptions
        }


init : Root.Startup -> Navigation.Location -> ( Root.Model, Cmd Msg )
init startup location =
    let
        currentRoute =
            (Routing.parseLocation location)

        initialState =
            Root.State.initialState startup.windowInnerWidth startup.time

        routeState =
            case currentRoute of
                Routing.ChannelRoute channelId ->
                    { initialState | activeChannelId = Just channelId }

                _ ->
                    initialState

        ( model, cmd ) =
            Root.State.restoreSavedState startup.savedState routeState
                |> Root.State.loadSettings
    in
        ( model, cmd )


subscriptions : Root.Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.broadcasterStateActions
        , Ports.receiverStatusActions
        , Ports.receiverPresenceActions
        , Ports.channelStatusActions
        , Ports.channelRemovalActions
        , Ports.renditionProgressActions
        , Ports.renditionChangeActions
        , Ports.renditionActivationActions
        , Ports.volumeChangeActions
        , Ports.playListAdditionActions
        , Ports.libraryRegistrationActions
        , Ports.libraryResponseActions
        , Ports.windowStartupActions
        , Ports.channelAdditionActions
        , Ports.channelRenameActions
        , Ports.receiverRenameActions
        , Ports.receiverMutingActions
        , Ports.scrollTopActions
        , Ports.connectionStatusActions
        , viewportWidth
        , Ports.animationScrollActions
        , Ports.applicationSettingsActions
        ]


viewportWidth : Sub Msg
viewportWidth =
    Window.resizes (\size -> Msg.BrowserViewport size.width)
