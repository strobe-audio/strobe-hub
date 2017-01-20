module Library exposing (..)

import Time exposing (Time)
import Utils.Touch
import Stack exposing (Stack)
import Animation


type Msg
    = NoOp
    | ExecuteAction Action String
    | MaybeExecuteAction (Maybe Action) String
    | Response ActionURL (Maybe Folder)
    | PopLevel Int
    | ActionComplete
    | Touch (Utils.Touch.E Msg)
    | AnimationFrame Time


type alias ActionURL =
    String


type alias Action =
    { url : ActionURL
    , level : Bool
    }



-- can serialise this as just `action` and restore as
-- {action = "<action>", contents = Nothing}


type alias Level =
    { action : ActionURL
    , title : String
    , contents : Maybe Folder
    }


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
    { levels : Stack Level
    , depth : Int
    , currentRequest : Maybe ActionURL
    , unloadingLevel : Maybe Level
    , touches : Utils.Touch.Model
    , animationTime : Maybe Time
    , levelAnimation : Animation.Animation
    }


type alias FolderResponse =
    { libraryId : String
    , url : ActionURL
    , folder : Maybe Folder
    }


type alias Metadata =
    List Link


type alias Link =
    { title : String
    , action : Maybe Action
    }


type alias Actions =
    { click : Action
    , play : Maybe Action
    }



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
