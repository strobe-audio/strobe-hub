module Routing exposing (..)

import Navigation exposing (Location)
import UrlParser exposing (..)
import ID


type Route
    = DefaultChannelRoute
    | ChannelRoute ID.Channel
    | NotFoundRoute


matchers : Parser (Route -> a) a
matchers =
    oneOf
        [ map DefaultChannelRoute top
        , map ChannelRoute (s "channels" </> string)
        ]


parseLocation : Location -> Route
parseLocation location =
    case (parsePath matchers location) of
        Just route ->
            route

        Nothing ->
            NotFoundRoute


channelLocation : ID.Channel -> String
channelLocation id =
    ("/channels/" ++ id)
