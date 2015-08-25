Otis
====

```elixir

{:ok, zone} = Otis.Zones.start_zone("downstairs", "Downstairs")

Otis.Zones.list

{:ok, recs} = Otis.Receivers.list
rec = List.first recs

Otis.Zone.add_receiver zone, rec

{:ok, ss} = Otis.Zone.source_stream(zone)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Seafile/Projects/streaming-music/otis/audio/Snake_Rag.mp3")

Otis.SourceStream.append_source(ss, source)

```
