Otis
====

```elixir

{:ok, zone} = Otis.Zones.start_zone("downstairs", "Downstairs")

{:ok, aine} = Otis.Receiver.start_link("aine", :"aine@192.168.1.89")
{:ok, garry} = Otis.Receiver.start_link("garry", :"garry@192.168.1.64")

Otis.Zone.add_receiver(zone, aine)
Otis.Zone.add_receiver(zone, garry)

{:ok, ss} = Otis.Zone.source_list(zone)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/bottle_160bpm_4-4time_80beats_stereo_a4kbLz.mp3")
Otis.SourceList.append(ss, source)

Otis.Zone.play_pause(zone)

#############
# Office
#############

{:ok, zone} = Otis.Zones.find "downstairs"
## 5m Silence

{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/5m-silence.mp3")
Otis.SourceList.append(ss, source)
Otis.Zone.play_pause(zone)

## 1 hr silence
{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
Enum.each 1..12, fn(_) ->
  {:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/5m-silence.mp3")
  Otis.SourceList.append(ss, source)
end
Otis.Zone.play_pause(zone)

## 5 hr silence
{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
Enum.each 1..60, fn(_) ->
  {:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/5m-silence.mp3")
  Otis.SourceList.append(ss, source)
end
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/SongMaven-Click-Track-120-BPM.mp3")
Otis.SourceList.append(ss, source)

Otis.Zone.play_pause(zone)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Unknown Artist/Unknown Album/Lady Sovereign - All Eyes On Me (garage).mp3")
Otis.SourceList.append(ss, source)

Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/apex-twin--peek-824545201.m4a")
Otis.SourceList.append(ss, source)
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "office"
{:ok, zone} = Otis.Zones.find(Otis.State.Zone.first.id)
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/shubert-piano-quintet.m4a")
Otis.SourceList.append(ss, source)
Otis.Zone.play_pause(zone)


{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/shubert-piano-quintet.m4a")
Otis.SourceList.append(ss, source)
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Oliver Jeffers/How to catch a star/01 Untitled.m4a")
Otis.SourceList.append(ss, source)
Otis.Zone.play_pause(zone)

## Albums


{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)

{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Music/iTunes/iTunes Media/Music/Richard Dawson/The Magic Bridge")
Otis.SourceList.append(ss, sources)
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Music/iTunes/iTunes Media/Music/Richard Dawson/The Glass Trunk")
Otis.SourceList.append(ss, sources)
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Music/iTunes/iTunes Media/Music/Richard Dawson/Nothing Important")
Otis.SourceList.append(ss, sources)

Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Seafile/Peep/audio/Tomorrow's Modern Boxes")
Otis.SourceList.append(ss, sources)
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory("/Users/garry/Seafile/Peep/audio/Tomorrow's Modern Boxes")
Otis.SourceList.append(ss, sources)
Otis.Zone.play_pause(zone)


Otis.Zone.skip(zone, "585747910cf6af2ba29fecd8b13eeb77")
Otis.Zone.skip(zone, "3c283aeb0c669255fe59359b97a11616")



{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)

{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Jackson 5/Jackson 5_ The Ultimate Collection"
Otis.SourceList.append(ss, sources)

Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I"
Otis.SourceList.append(ss, sources)

Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Deerhoof/Milk Man"
Otis.SourceList.append(ss, sources)
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Pixies/Doolittle"
Otis.SourceList.append(ss, sources)

{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Westing (By Musket And Sextant)"
Otis.SourceList.append(ss, sources)


# CELLO
{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, sources} = Otis.Filesystem.directory "/Users/garry/Music/iTunes/iTunes Media/Music/Compilations/Cello Suites 1, 4 & 5"
Otis.SourceList.append(ss, sources)
Otis.Zone.play_pause(zone)

## Pavement

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/01 Texas Never Whispers.m4a")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/02 Frontwards.m4a")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/03 Lions.m4a")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Pavement/Watery Domestic/04 Shoot The Singer.m4a")
Otis.SourceList.append(ss, source)



## SHORT SAMPLE
{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)

{:ok, zone} = Otis.Zones.find(Otis.State.Zone.first.id)
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/song.mp3")
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.SourceList.append(ss, source)
Otis.Zone.play_pause(zone)

{:ok, zone} = Otis.Zones.find "office"
{:ok, ss} = Otis.Zone.source_list(zone)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/song.mp3")
Otis.SourceList.append(ss, source)


{:ok, zone} = Otis.Zones.find "downstairs"
{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/song.mp3")
Otis.SourceList.append(ss, source)

{:ok, zone} = Otis.Zones.find(Otis.State.Zone.first.id)
Otis.Zone.play_pause(zone)

#############

{:ok, zone} = Otis.Zones.find "downstairs"

{:ok, ss} = Otis.Zone.source_list(zone)
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/SongMaven-Click-Track-120-BPM.mp3")
Otis.SourceList.append(ss, source)

Otis.Zone.play_pause(zone)


#############
{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/10 Somebody To Love.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/17 We Are The Champions.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Music/iTunes/iTunes Media/Music/Queen/Greatest Hits I/03 Killer Queen.mp3")
Otis.SourceList.append(ss, source)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/Snake_Rag.mp3")
Otis.SourceList.append(ss, source)

###############


{:ok, zone} = Otis.Zones.start_zone("office", "Office")

{:ok, mac} = Otis.Receiver.start_link("mac", :"janis@garry-macpro-11")

Otis.Zone.add_receiver(zone, mac)

{:ok, ss} = Otis.Zone.source_list(zone)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceList.append(ss, source)

Otis.Zone.play_pause(zone)

###############


{:ok, zone} = Otis.Zones.start_zone("office", "Office")

{:ok, mac} = Otis.Receiver.start_link("mac", :"janis@garry-macpro-11")

Otis.Zone.add_receiver(zone, mac)

{:ok, ss} = Otis.Zone.source_list(zone)

{:ok, source} = Otis.Source.File.new("/Users/garry/Seafile/Peep/audio/rag.mp3")
Otis.SourceList.append(ss, source)

Otis.Zone.play_pause(zone)

```
