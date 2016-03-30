module Library where


import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Effects exposing (Effects, Never)
import Task exposing (Task)
import Debug


type Action
  = NoOp
  | ExecuteAction Definition String
  | Response Folder


type alias Folder =
  { id : String
  , title : String
  , icon : String
  , action : String
  , children : List Node
  }


type alias Node =
  { id : String
  , title : String
  , icon : String
  , action : String
  }


type alias Definition =
  { name : String
  , id : String
  , levels : List Folder
  , level : Folder
  , action : String
  }

type alias FolderResponse =
  { libraryId : String
  , folder : Folder
  }


rootLevel : Definition -> Folder
rootLevel library =
  { id = library.id
  , title = library.name
  , icon = ""
  , action = library.action
  , children = []
  }

pushLevel : Definition -> Folder -> Definition
pushLevel library folder =
  Debug.log ("pushLevel " ++ (toString library) ++ " " ++ (toString folder))
  { library | levels = (library.level :: library.levels), level = folder }

init : Definition -> Definition
init library =
  -- TODO: initialize the root level (which is just the library name and icon)
  { library  | level = rootLevel library }


update : Action -> Definition -> (Definition, Effects Action)
update action model =
  case action of
    NoOp ->
      ( model, Effects.none )

    ExecuteAction library a ->
      ( model, ( sendAction library a ) )

    Response folder ->
      Debug.log (" RESPONSE " ++ (toString folder))
      ( (pushLevel model folder), Effects.none )


node : Signal.Address Action -> Definition -> Folder -> Node -> Html
node address library folder node =
  div [ onClick address (ExecuteAction library node.action) ] [ text node.title ]


folder : Signal.Address Action -> Definition -> Folder -> Html
folder address library folder =
  let
      children = if List.isEmpty folder.children then
        div [] []
      else
        div [ class "content" ] (List.map (node address library folder) folder.children )

  in
      Debug.log (" folder " ++ (toString folder))
      div [ class "ui card" ] [
        div [ class "content" ] [
          div [ class "header", onClick address (ExecuteAction library folder.action) ] [ text folder.title ]
          ]
        , children
      ]


root : Signal.Address Action -> Definition -> Html
root address library =
  folder address library library.level


libraryRequestsBox : Signal.Mailbox String
libraryRequestsBox =
  Signal.mailbox ""


sendAction : Definition -> String -> Effects Action
sendAction library action =
  Signal.send libraryRequestsBox.address action
    |> Effects.task
    |> Effects.map (always NoOp)




