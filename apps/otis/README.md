Otis
====

```elixir

{:ok, zone} = Otis.Zones.start_zone("downstairs", "Downstairs")
{:ok, recs} = Otis.Receivers.list
Enum.each recs, fn(rec) -> Otis.Zone.add_receiver(zone, rec) end
{:ok, ss} = Otis.Zone.source_stream(zone)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceStream.append_source(ss, source)

Otis.Zone.play_pause(zone)

#############

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/10 Somebody To Love.mp3")
Otis.SourceStream.append_source(ss, source)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/17 We Are The Champions.mp3")
Otis.SourceStream.append_source(ss, source)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/03 Killer Queen.mp3")
Otis.SourceStream.append_source(ss, source)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Seafile/Peep/audio/Snake_Rag.mp3")
Otis.SourceStream.append_source(ss, source)
```
