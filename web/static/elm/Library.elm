module Library (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Effects exposing (Effects, Never)
import Task exposing (Task)
import Debug
import String


type Action
  = NoOp
  | ExecuteAction String
  | Response Folder
  | PopLevel Int



{-

folders:

- album:
  - cover art
  - title
  - artist
  - year
  - genre
  - duration

nodes:

- album
  - cover art
  - title
  - artist
  - year
  - track count


actions:

- primary (click)
- secondary (double click/long tap)?

- options:
  - append
  - next
  - now

  - edit?
  - delete?

e.g. for song

desktop:
- primary action: click
- secondary action: double click
- tertiary: long click
- quaternary: swipe right
- quinary: swipe left

mobile:
- primary action: tap
- secondary action: double tap
- tertiary: long tap
- quaternary: swipe right
- quinary: swipe left


uses:

- primary: append to playlist
- secondary: play now
- tertiary: re-order?
- quaternary: reveal another list of actions
- quinary: reveal list of actions

```
{
  actions: {
    primary: "peep:play",
    secondary: "peep:play-now",
    tertiary: {
      edit: "",
      delete: "",
      play: ""
    }
  }
}
```

question: how to encode the actions embedded behind the swipe actions? what are the generic set of things you can do?

swipe left (quaternary) - [play now, play next, append]
swipe right (quinary) - [edit, delete]

ui maps events (click dblclick, swipel/r) to effects (send action, reveal buttons, etc)
set of actions are always the same:

```
{
  play-now: "...",
  play-next: "...",
  play-append: "...",
  edit: "...",
  delete: "...",
}
```

library entirely responsible for the action action string



in the playlist artist name & album name (& any other metadata) must have actions attached too. you should be able to click on the artist of a playlist entry & go to the library view for that artist..

-}


type alias Folder =
  { id : String
  , title : String
  , icon : String
  , children : List Node
  }


type alias Node =
  { id : String
  , title : String
  , icon : String
  , action : String
  }


type alias Model =
  { levels : List Folder
  }


type alias FolderResponse =
  { libraryId : String
  , folder : Folder
  }



-- rootLevel : Model -> Folder
-- rootLevel library =
--   { id = library.id
--   , title = library.name
--   , icon = ""
--   , action = library.action
--   , children = []
--   }


pushLevel : Model -> Folder -> Model
pushLevel model folder =
  -- Debug.log ("pushLevel |" ++ (toString folder) ++ "| |" ++ (toString model.level) ++ "| ")
  { model | levels = (folder :: model.levels) }


init : Model
init =
  let
    root =
      { id = "libraries", title = "Libraries", icon = "", children = [] }
  in
    { levels = [ root ] }


add : Model -> Node -> Model
add model library =
  let
    levels =
      (List.reverse model.levels)

    root =
      case (List.head levels) of
        Just level ->
          { level | children = (library :: level.children) }

        Nothing ->
          Debug.crash "Model has no root level!"

    others =
      case List.tail levels of
        Just l ->
          l

        Nothing ->
          []
  in
    { model | levels = (List.reverse (root :: others)) }


update : Action -> Model -> String -> ( Model, Effects Action )
update action model zoneId =
  case action of
    NoOp ->
      ( model, Effects.none )

    ExecuteAction a ->
      ( model, (sendAction zoneId a) )

    Response folder ->
      ( (pushLevel model folder), Effects.none )

    PopLevel index ->
      ( { model | levels = List.drop index model.levels }, Effects.none )


node : Signal.Address Action -> Model -> Folder -> Node -> Html
node address library folder node =
  div [ class "block", onClick address (ExecuteAction node.action) ] [ text node.title ]


breadcrumb : Signal.Address Action -> Model -> Folder -> Html
breadcrumb address model folder =
  let
    breadcrumbLink classes index level =
      -- Debug.log ("level " ++ level.action)
      a [ class classes, onClick address (PopLevel (index + 1)) ] [ text level.title ]

    sections =
      case List.tail model.levels of
        Just levels ->
          List.indexedMap (breadcrumbLink "section") levels

        Nothing ->
          []

    levels =
      (div [ class "section active" ] [ text folder.title ]) :: sections

    breadcrumb =
      List.intersperse (i [ class "right angle icon divider" ] []) levels
  in
    div [ class "ui breadcrumb" ] (List.reverse breadcrumb)


folder : Signal.Address Action -> Model -> Folder -> Html
folder address model folder =
  let
    children =
      if List.isEmpty folder.children then
        div [] []
      else
        div [ class "block-group library-contents" ] (List.map (node address model folder) folder.children)
  in
    -- Debug.log (" folder " ++ (toString folder))
    div
      []
      [ div
          [ class "block-group library-folder" ]
          [ div
              [ class "library-breadcrumb" ]
              [ (breadcrumb address model folder)
              ]
          ]
      , children
      ]


currentLevel : Model -> Folder
currentLevel model =
  case List.head model.levels of
    Just level ->
      level

    Nothing ->
      Debug.crash "Model has no root level!"


root : Signal.Address Action -> Model -> Html
root address model =
  folder address model (currentLevel model)


libraryRequestsBox : Signal.Mailbox ( String, String )
libraryRequestsBox =
  Signal.mailbox ( "", "" )


sendAction : String -> String -> Effects Action
sendAction zoneId action =
  Signal.send libraryRequestsBox.address ( zoneId, action )
    |> Effects.task
    |> Effects.map (always NoOp)
