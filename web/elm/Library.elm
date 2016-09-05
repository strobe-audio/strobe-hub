module Library exposing (..)

-- import Html exposing (..)
-- import Html.Attributes exposing (..)
-- import Html.Events exposing (..)
-- import Debug
-- import String


type Msg
  = NoOp
  | ExecuteAction String
  | MaybeExecuteAction (Maybe String)
  | Response Folder
  | PopLevel Int
  | ActionComplete



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
  , actions : Actions
  , metadata : Maybe (List Metadata)
  }


type alias Model =
  { levels : List Folder
  , currentRequest : Maybe String
  }


type alias FolderResponse =
  { libraryId : String
  , folder : Folder
  }

type alias Metadata =
  List Link

type alias Link =
  { title: String
  , action : Maybe String
  }

type alias Actions =
  { click : String
  , play : Maybe String
  }
-- rootLevel : Model -> Folder
-- rootLevel library =
--   { id = library.id
--   , title = library.name
--   , icon = ""
--   , action = library.action
--   , children = []
--   }
