module Stack exposing (initialise, push, pop, toList, fromList, Stack)

{-| This library implements a stack data structure in Elm, allowing you to worry more about your business logic and less about implementing common adts.

# Definition
@docs Stack

# Initialisation
@docs initialise

# Common Helpers
@docs pop, push, toList

-}


{-| -}
type Stack a
    = Stack (List a)


{-| Initialise an empty stack.
-}
initialise : Stack a
initialise =
    Stack []


{-| Convert a Stack type to a list data type
-}
toList : Stack a -> List a
toList (Stack stack) =
    stack


fromList : List a -> Stack a
fromList a =
    Stack a


{-| Pushes an item onto the stack and returns the new stack. The item must be of the same type as the stack.
-}
push : a -> Stack a -> Stack a
push item (Stack stack) =
    Stack (item :: stack)


{-| Removes the item at the top of the stack and returns it as the first item of a tuple.
-}
pop : Stack a -> ( Maybe a, Stack a )
pop (Stack stack) =
    let
        item =
            List.head stack

        tail =
            List.tail stack
    in
        case item of
            Nothing ->
                ( Nothing, Stack stack )

            Just item ->
                let
                    newstack =
                        case tail of
                            Nothing ->
                                []

                            Just tail ->
                                tail
                in
                    ( Just item, Stack newstack )
