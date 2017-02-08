module Library exposing (..)

import Time exposing (Time)
import Utils.Touch
import Stack exposing (Stack)
import Animation
import List.Extra


type Msg
    = NoOp
    | ExecuteAction Action String (Maybe String)
    | MaybeExecuteAction (Maybe Action) String
    | Response ActionURL (Maybe Folder)
    | PopLevel Int
    | ActionComplete
    | Touch (Utils.Touch.E Msg)
    | AnimationFrame (Time, Maybe Float, Float)
    | ShowSearchInput Bool
    | SearchQueryUpdate String
    | SubmitSearch
    | CancelSearch
    | SearchTimeout Int


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
    , scrollHeight : Float
    , scrollPosition : Float
    }

type alias SearchAction =
    { url : ActionURL
    , title : String
    }


type alias Folder =
    { id : String
    , title : String
    , icon : String
    , search : Maybe SearchAction
    , children : List Section
    }


type alias Section =
    { id : String
    , title : String
    , actions : Maybe Actions
    , metadata : Maybe (List Metadata)
    , icon : Maybe String
    , size : String
    , children : List Node
    }


type alias Node =
    -- { id : String
    { title : String
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
    , showSearchInput : Bool
    , searchQuery : String
    , searchBounceCount : Int
    , scrollMomentum : Maybe Utils.Touch.Momentum
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

type Renderable
    = N String Node
    | S Section


type alias FolderView =
    { renderable : List Renderable
    , height : Float
    -- , firstNodeHeight : Float
    , firstNodePosition : Float
    }


defaultNodeActions : Actions
defaultNodeActions =
    { click = { url = "", level = False }
    , play = Nothing
    }

nodeHeight : Float
nodeHeight =
    60.0

levelContentHeight : Level -> Maybe Float
levelContentHeight level =
    level.contents |> Maybe.map (\f -> folderContentHeight f)


folderContentCount : Folder -> Int
folderContentCount folder =
    (List.map sectionCount folder.children) |> List.sum

folderContentHeight : Folder -> Float
folderContentHeight folder =
    (List.map sectionHeight folder.children) |> List.sum


contentHeight : Int -> Float
contentHeight n =
    n |> toFloat |> (*) nodeHeight



sectionNode : Section -> Node
sectionNode section =
    { title = section.title
    , icon = Maybe.withDefault "" section.icon
    , actions = Maybe.withDefault defaultNodeActions section.actions
    , metadata = section.metadata
    }

sectionCount : Section -> Int
sectionCount section =
    List.length section.children


sectionHeight : Section -> Float
sectionHeight section =
    (sectionNodeHeight section) + (contentHeight (List.length section.children))


sectionNodeHeight : Section -> Float
sectionNodeHeight section =
    case section.size of
        "i" ->
            0

        "s" ->
            nodeHeight / 2

        "m" ->
            nodeHeight

        "l" ->
            nodeHeight * 2

        "h" ->
            nodeHeight * 5

        _ ->
            nodeHeight


renderableHeight : List Renderable -> Float
renderableHeight renderable =
    renderable |> List.map renderableNodeHeight |> List.sum


renderableNodeHeight : Renderable -> Float
renderableNodeHeight renderable =
    case renderable of
        S section ->
            sectionNodeHeight section

        N _ _ ->
            nodeHeight


renderableFirstNodeHeight : List Renderable -> Float
renderableFirstNodeHeight renderable =
    case renderable of
        first :: rest ->
            renderableNodeHeight first

        [] ->
            0.0

renderableNodes : Int -> String -> List Node -> List Renderable
renderableNodes offset id children =
    List.range offset (offset + (List.length children - 1))
        |> List.Extra.zip children
            |> List.map (\(c, i) -> N (id ++ (toString i)) c)


sectionRenderableNodes : Section -> List Renderable
sectionRenderableNodes section =
    renderableNodes 0 section.id section.children

takeSection : Int -> Section -> List Renderable
takeSection take section =
    List.take take section.children
        |> renderableNodes 0 section.id


dropSection : Int -> Section -> List Renderable
dropSection drop section =
    List.drop drop section.children
        |> renderableNodes drop section.id


sliceSection : Int -> Int -> Section -> List Renderable
sliceSection drop take section =
    List.drop drop section.children
        |> List.take take
            |> renderableNodes drop section.id
