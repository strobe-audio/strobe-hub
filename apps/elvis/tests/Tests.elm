module Tests exposing (..)

import Test exposing (..)
import Expect
import Fuzz exposing (list, int, tuple, string)
import String
import Library exposing (Renderable(..))
import Library.View


all : Test
all =
    describe "Elvis"
        [ libraryTests
        , libraryViewTests
        ]


sn : Library.Section -> List Renderable
sn section =
    Library.sectionRenderableNodes section


libraryTests : Test
libraryTests =
    describe "Library"
        [ test "sectionNodeHeight" <|
            \() ->
                Expect.equal (Library.sectionNodeHeight sE) 30.0
        , test "sectionRenderableNodes" <|
            \() ->
                Expect.equalLists
                    (Library.sectionRenderableNodes sD)
                    [ N "d0" (exampleNode "d" 0)
                    , N "d1" (exampleNode "d" 1)
                    , N "d2" (exampleNode "d" 2)
                    ]
        , test "dropSection" <|
            \() ->
                Expect.equalLists
                    (Library.dropSection 1 sD)
                    [ N "d1" (exampleNode "d" 1)
                    , N "d2" (exampleNode "d" 2)
                    ]
        , test "sliceSection 1 1" <|
            \() ->
                Expect.equalLists
                    (Library.sliceSection 1 1 sD)
                    [ N "d1" (exampleNode "d" 1)
                    ]
        , test "sliceSection 2 1" <|
            \() ->
                Expect.equalLists
                    (Library.sliceSection 2 1 sD)
                    [ N "d2" (exampleNode "d" 2)
                    ]
        ]


libraryViewTests : Test
libraryViewTests =
        describe "Library.View"
            [ test "folderViewOpenWindow 0 300" <|
                \() ->
                        (testFolderView
                            0
                            300
                            [ [(S sA)]
                            , (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            ]
                            0
                        )
            , test "folderViewOpenWindow -1 330" <|
                \() ->
                        (testFolderView
                            -1
                            330
                            [ [(S sA)]
                            , (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            , [(S sD)]
                            ]
                            0
                        )
            , test "folderViewOpenWindow -10 300" <|
                \() ->
                        (testFolderView
                            -10
                            300
                            [ [(S sA)]
                            , (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            ]
                            0
                        )
            , test "folderViewOpenWindow -23 300" <|
                \() ->
                        (testFolderView
                            -23
                            300
                            [ [(S sA)]
                            , (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            ]
                            0
                        )
            , test "folderViewOpenWindow -31 300" <|
                \() ->
                        (testFolderView
                            -31
                            300
                            [ (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            , [(S sD)]
                            ]
                            30.0
                        )
            , test "folderViewOpenWindow -60 300" <|
                \() ->
                        (testFolderView
                            -60
                            300
                            [ (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            , [(S sD)]
                            ]
                            30.0
                        )
            , test "folderViewOpenWindow -61 300" <|
                \() ->
                        (testFolderView
                            -61
                            300
                            [ (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            , [(S sD)]
                            , (Library.takeSection 1 sD)
                            ]
                            30.0
                        )
            , test "folderViewOpenWindow -80 300" <|
                \() ->
                        (testFolderView
                            -80
                            300
                            [ (sn sA)
                            , [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            , [(S sD)]
                            , (Library.takeSection 1 sD)
                            ]
                            30.0
                        )
            , test "folderViewOpenWindow -90 300" <|
                \() ->
                        (testFolderView
                            -90
                            300
                            [ [(S sB)]
                            , (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            , [(S sD)]
                            , (Library.takeSection 1 sD)
                            ]
                            90.0
                        )
            , test "folderViewOpenWindow -121 300" <|
                \() ->
                        (testFolderView
                            -121
                            300
                            [ (sn sB)
                            , [(S sC)]
                            , (sn sC)
                            , [(S sD)]
                            , (Library.takeSection 2 sD)
                            ]
                            120.0
                        )
            , test "folderViewOpenWindow -523 300" <|
                \() ->
                        (testFolderView
                            -523
                            300
                            [ (Library.dropSection 2 sD)
                            , [(S sE)]
                            , (Library.takeSection 5 sE)
                            ]
                            480.0
                        )
            , test "folderViewOpenWindow -523 300" <|
                \() ->
                        (testFolderView
                            -588
                            300
                            [ (Library.takeSection 6 sE)
                            ]
                            570.0
                        )
            , test "folderViewOpenWindow -931 300" <|
                \() ->
                        (testFolderView
                            -931
                            300
                            [ (Library.dropSection 6 sE)
                            ]
                            930.0
                        )
            ]


testFolderView : Float -> Float -> List (List Renderable) -> Float -> Expect.Expectation
testFolderView position height expectedRenderables expectedPosition =
    let
        level =
            (exampleLevelScrolled position height)

        folder =
            level.contents |> (Maybe.withDefault exampleFolder)

        (folderView, firstNodePosition) =
            (Library.View.folderViewOpenWindow level folder.children 0.0)

    in
        Expect.all
            [ (\(r, p) ->
                Expect.equalLists
                folderView
                (List.concat expectedRenderables)
              )
            , (\(r, p) ->
                Expect.equal p expectedPosition
              )
            ]
            (folderView, firstNodePosition)



exampleLevelScrolled : Float -> Float -> Library.Level
exampleLevelScrolled position height =
    let
        level =
            exampleLevel
    in
        { level | scrollPosition = position, scrollHeight = height }

exampleLevel : Library.Level
exampleLevel =
    { action = ""
    , title = "Example level"
    , contents = Just exampleFolder
    , scrollHeight = 320
    , scrollPosition = 0
    , visible = True
    }

exampleFolder : Library.Folder
exampleFolder =
    { id = "test:example-folder"
    , title = "Test Example Folder"
    , icon = ""
    , search = Nothing
    , children = exampleSections
    }


generateSection : String -> String -> List Library.Node -> Library.Section
generateSection id size children =
    { id = id
    , title = id
    , actions = Nothing
    , metadata = Nothing
    , icon = Nothing
    , size = size
    , children = children
    , length = List.length children
    }

exampleNode : String -> Int -> Library.Node
exampleNode label n =
    { title = label ++ (toString n)
    , icon = Nothing
    , actions =
        { click = { url = "", level = False }
        , play = Nothing
        }
    , metadata = Nothing
    }

exampleNodes : String -> Int -> List Library.Node
exampleNodes label count =
    List.range 0 (count - 1)
        |> List.map (exampleNode label)


exampleSections : List Library.Section
exampleSections =
    [ sA , sB , sC , sD , sE ]

sA : Library.Section
sA =
    generateSection "a" "s"  (exampleNodes "a" 1)

sB : Library.Section
sB =
    generateSection "b" "s"  (exampleNodes "b" 1)

sC : Library.Section
sC =
    generateSection "c" "s"  (exampleNodes "c" 2)

sD : Library.Section
sD =
    generateSection "d" "s"  (exampleNodes "d" 3)

sE : Library.Section
sE =
    generateSection "e" "s"  (exampleNodes "e" 10)
