Otis
====

```elixir

{:ok, zone} = Otis.Zones.start_zone("downstairs", "Downstairs")

{:ok, aine} = Otis.Receiver.start_link("aine", :"aine@192.168.1.89")
{:ok, garry} = Otis.Receiver.start_link("garry", :"garry@192.168.1.64")

Otis.Zone.add_receiver(zone, aine)
Otis.Zone.add_receiver(zone, garry)

{:ok, ss} = Otis.Zone.source_stream(zone)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Seafile/Peep/audio/bottle_160bpm_4-4time_80beats_stereo_a4kbLz.mp3")
Otis.SourceStream.append_source(ss, source)

Otis.Zone.play_pause(zone)

#############
{:ok, source} = Otis.Source.File.from_path("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceStream.append_source(ss, source)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/10 Somebody To Love.mp3")
Otis.SourceStream.append_source(ss, source)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/17 We Are The Champions.mp3")
Otis.SourceStream.append_source(ss, source)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/03 Killer Queen.mp3")
Otis.SourceStream.append_source(ss, source)

{:ok, source} = Otis.Source.File.from_path("/Users/garry/Seafile/Peep/audio/Snake_Rag.mp3")
Otis.SourceStream.append_source(ss, source)
```
