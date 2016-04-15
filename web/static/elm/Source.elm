module Source where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


metadataWithFallback : Maybe String -> String -> String
metadataWithFallback maybe fallback =
  case maybe of
    Just value -> value
    Nothing -> fallback


entryTitle : PlaylistEntry -> String
entryTitle entry =
  metadataWithFallback entry.source.metadata.title "Untitled"


entryAlbum : PlaylistEntry -> String
entryAlbum entry =
  metadataWithFallback entry.source.metadata.album "Untitled Album"


entryPerformer : PlaylistEntry -> String
entryPerformer entry =
  metadataWithFallback entry.source.metadata.performer ""

zoneSources : Model -> Zone -> List PlaylistEntry
zoneSources model zone =
  List.filter (\e -> e.zoneId == zone.id) model.sources

zonePlaylist : Model -> Zone -> ZonePlaylist
zonePlaylist model zone =
  let
      all = List.filter (\e -> e.zoneId == zone.id) model.sources
      |> List.sortBy (\e -> e.position)
      entries = case (List.tail all) of
        Just e  -> e
        Nothing -> []
  in
    { active = (List.head all), entries = entries }


playlistEntry : Signal.Address Action -> PlaylistEntry -> Html
playlistEntry address entry =
  div [ key entry.id, class "block playlist-entry", onDoubleClick address (PlaylistSkip entry) ] [
    div [ class "playlist-entry--title" ] [
      strong [] [ text (entryTitle entry) ]
    ]
  , div [ class "playlist-entry--album" ] [
      strong [] [ text (entryPerformer entry) ]
    , text ", "
    , text (entryAlbum entry)
    ]
  ]


-- playlistEntryProgress : Signal.Address Action -> PlaylistEntry -> Html
-- playlistEntryProgress address entry =
--   case entry.source.metadata.duration_ms of
--     Nothing ->
--       div [ ] [ ]
--     Just duration ->
--       let
--           percent = 100.0 * (toFloat entry.playbackPosition) / (toFloat duration)
--           progressStyle = [ ("width", (toString percent) ++ "%") ]
--       in
--         div [ class "playlist-entry-progress" ] [
--           div [ class "playlist-entry-progress--outer ui tiny red progress" ] [
--             div [ class "playlist-entry-progress--inner bar", style progressStyle ] [ ]
--           ]
--         ]


-- activePlaylistEntry : Signal.Address Action -> Maybe PlaylistEntry -> Html
-- activePlaylistEntry address active =
--   case active of
--     Nothing ->
--       div [] [ text "Nothing" ]
--     Just entry ->
--       div [ class "active-playlist-entry" ] [
--         (playlistEntry address entry)
--       , (playlistEntryProgress address entry)
--       ]
