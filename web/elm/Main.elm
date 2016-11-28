module Main exposing (main)

import Debug
import Html
import Msg exposing (Msg)
import Window
import Root
import Root.State
import Root.View
import Ports
import Navigation
import Routing


main =
    Navigation.program Msg.UrlChange
        { init = init
        , view = Root.View.root
        , update = Root.State.update
        , subscriptions = subscriptions
        }


init : Navigation.Location -> ( Root.Model, Cmd Msg )
init location =
    let
        currentRoute =
            (Routing.parseLocation location)

        initialState =
            Root.State.initialState

        state =
            case currentRoute of
                Routing.ChannelRoute channelId ->
                    { initialState | activeChannelId = Just channelId }

                _ ->
                    initialState
    in
        ( state, Cmd.none )


subscriptions : Root.Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.broadcasterStateActions
        , Ports.receiverStatusActions
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
        , viewportWidth
        ]


viewportWidth : Sub Msg
viewportWidth =
    Window.resizes (\size -> Msg.BrowserViewport size.width)
