module Settings.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Settings
import Msg exposing (Msg)
import Root
import Channel
import Receiver
import Utils.Touch exposing (onSingleTouch)
import Input.View


configure : Root.Model -> Html Msg
configure model =
    let
        configuration =
            model.configuration

        view =
            case configuration.viewMode of
                Settings.Channels ->
                    channelsConfiguration model

                Settings.Receivers ->
                    receiversConfiguration model

                Settings.Settings ->
                    (application configuration.settings)
    in
        div [ class "configuration-container" ]
            [ viewModeSwitchTabs configuration
            , div [ class "configuration-scrollable", id "__scrolling__" ]
                [ view
                ]
            ]


viewModeSwitchTabs : Root.Configuration -> Html Msg
viewModeSwitchTabs configuration =
    div
        [ class "settings--view-mode-tabs" ]
        [ div
            [ classList
                [ ( "settings--view-mode-tab settings--view-mode-tab__channels", True )
                , ( "settings--view-mode-tab__active", (configuration.viewMode == Settings.Channels) )
                ]
            , onClick (Msg.SetConfigurationViewModel Settings.Channels)
            , onSingleTouch (Msg.SetConfigurationViewModel Settings.Channels)
            ]
            [ text "Channels" ]
        , div
            [ classList
                [ ( "settings--view-mode-tab settings--view-mode-tab__receivers", True )
                , ( "settings--view-mode-tab__active", (configuration.viewMode == Settings.Receivers) )
                ]
            , onClick (Msg.SetConfigurationViewModel Settings.Receivers)
            , onSingleTouch (Msg.SetConfigurationViewModel Settings.Receivers)
            ]
            [ text "Receivers" ]
        , div
            [ classList
                [ ( "settings--view-mode-tab settings--view-mode-tab__settings", True )
                , ( "settings--view-mode-tab__active", (configuration.viewMode == Settings.Settings) )
                ]
            , onClick (Msg.SetConfigurationViewModel Settings.Settings)
            , onSingleTouch (Msg.SetConfigurationViewModel Settings.Settings)
            ]
            [ text "Settings" ]
        ]


receiversConfiguration : Root.Model -> Html Msg
receiversConfiguration model =
    div []
        [ div [] (List.map (receiverConfiguration model) model.receivers)
        ]


receiverConfiguration : Root.Model -> Receiver.Model -> Html Msg
receiverConfiguration model receiver =
    let
        msg : Receiver.Msg -> Msg
        msg m =
            Msg.Receiver receiver.id m

        panel =
            case receiver.editName of
                True ->
                    receiverEditName model receiver

                False ->
                    div [] []
    in
        div
            [ class "settings--receiver" ]
            [ div
                [ class "settings--receiver--display" ]
                [ div [ class "settings--receiver--name" ] [ text receiver.name ]
                , div
                    [ class "settings--receiver--edit"
                    , onClick (msg (Receiver.ShowEditName True))
                    , onSingleTouch (msg (Receiver.ShowEditName True))
                    ]
                    []
                  -- TODO: do need a way to delete receivers
                  -- , div
                  --     [ class "settings--receiver--delete"
                  --     , onClick (msg (Receiver.ShowConfirmDelete True))
                  --     , onSingleTouch (msg (Receiver.ShowConfirmDelete True))
                  --     ]
                  --     []
                ]
            , panel
            ]


receiverEditName : Root.Model -> Receiver.Model -> Html Msg
receiverEditName model receiver =
    div
        [ class "settings--receiver--edit--input" ]
        [ Html.map ((Msg.Receiver receiver.id) << Receiver.EditName) (Input.View.inputSubmitCancel receiver.editNameInput)
        ]


channelsConfiguration : Root.Model -> Html Msg
channelsConfiguration model =
    let
        channels =
            model.channels
    in
        div []
            [ div [] [ (createChannel model) ]
            , div [] (List.map (channelConfiguration model) channels)
            ]


createChannel : Root.Model -> Html Msg
createChannel model =
    let
        panel =
            case model.showAddChannel of
                True ->
                    div
                        [ class "settings--channel-create--input" ]
                        [ Html.map Msg.AddChannelInput (Input.View.inputSubmitCancel model.newChannelInput) ]

                False ->
                    div [] []
    in
        div
            [ class "settings--channel-create" ]
            [ div
                [ class "settings--channel-create--button"
                , onClick (Msg.ToggleAddChannel)
                , onSingleTouch (Msg.ToggleAddChannel)
                ]
                [ div [ class "settings--channel-create--icon" ] []
                , div [ class "settings--channel-create--title" ] [ text "Add channel..." ]
                ]
            , panel
            ]


channelConfiguration : Root.Model -> Channel.Model -> Html Msg
channelConfiguration model channel =
    let
        msg : Channel.Msg -> Msg
        msg m =
            Msg.Channel channel.id m

        panel =
            case channel.confirmDelete of
                True ->
                    channelDeleteConfirmation model channel

                False ->
                    case channel.editName of
                        True ->
                            channelEditName model channel

                        False ->
                            div [] []
    in
        div
            [ class "settings--channel" ]
            [ div
                [ class "settings--channel--display" ]
                [ div [ class "settings--channel--name" ] [ text channel.name ]
                , div
                    [ class "settings--channel--edit"
                    , onClick (msg (Channel.ShowEditName True))
                    , onSingleTouch (msg (Channel.ShowEditName True))
                    ]
                    []
                , div
                    [ class "settings--channel--delete"
                    , onClick (msg (Channel.ShowConfirmDelete True))
                    , onSingleTouch (msg (Channel.ShowConfirmDelete True))
                    ]
                    []
                ]
            , panel
            ]


channelEditName : Root.Model -> Channel.Model -> Html Msg
channelEditName model channel =
    div
        [ class "settings--channel--edit--input" ]
        [ Html.map ((Msg.Channel channel.id) << Channel.EditName) (Input.View.inputSubmitCancel channel.editNameInput)
        ]


channelDeleteConfirmation : Root.Model -> Channel.Model -> Html Msg
channelDeleteConfirmation model channel =
    let
        msg : Channel.Msg -> Msg
        msg m =
            Msg.Channel channel.id m

        deleteConfirm =
            div
                [ class "settings--channel--confirm-delete" ]
                [ div [ class "settings--channel--confirm-delete--text" ] [ text "Really delete this channel?" ]
                , div
                    [ class "settings--channel--confirm-delete--confirm"
                    , onClick (msg (Channel.Remove))
                    , onSingleTouch (msg (Channel.Remove))
                    ]
                    []
                , div
                    [ class "settings--channel--confirm-delete--cancel"
                    , onClick (msg (Channel.ShowConfirmDelete False))
                    , onSingleTouch (msg (Channel.ShowConfirmDelete False))
                    ]
                    []
                ]

        cantDelete =
            div
                [ class "settings--channel--confirm-delete" ]
                [ div [ class "settings--channel--confirm-delete--text" ] [ text "You can’t delete the currently active channel" ]
                , div
                    [ class "settings--channel--confirm-delete--cancel"
                    , onClick (msg (Channel.ShowConfirmDelete False))
                    , onSingleTouch (msg (Channel.ShowConfirmDelete False))
                    ]
                    []
                ]
    in
        case model.activeChannelId of
            Nothing ->
                deleteConfirm

            Just id ->
                if id == channel.id then
                    cantDelete
                else
                    deleteConfirm


application : Maybe Settings.Model -> Html Msg
application maybeModel =
    case maybeModel of
        Nothing ->
            div [ class "settings-loading" ] [ text "loading..." ]

        Just model ->
            applicationSettings model


applicationSettings : Settings.Model -> Html Msg
applicationSettings model =
    div
        [ class "settings-container" ]
        [ div [ class "settings-namespaces" ] (List.map namespace model.namespaces)
        ]


namespace : Settings.NameSpace -> Html Msg
namespace ns =
    div
        [ class "settings-namespace" ]
        [ h3 [ class "settings-namespace__title" ] [ text ns.title ]
        , (fields ns.fields)
        ]


fields : Settings.Fields -> Html Msg
fields fields =
    div
        [ class "settings-fields" ]
        (List.map field fields)


field : Settings.Field -> Html Msg
field field =
    div
        [ class "settings-field" ]
        [ label [] [ text field.title ]
        , (fieldInput field)
        ]


fieldInput : Settings.Field -> Html Msg
fieldInput field =
    let
        change =
            onInput (Msg.UpdateApplicationSettings field)
    in
        case field.inputType of
            "password" ->
                input [ type_ "password", value field.value, name field.name, change ] []

            _ ->
                input [ type_ "text", value field.value, name field.name, change ] []
